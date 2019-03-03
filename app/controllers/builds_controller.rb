# frozen_string_literal: true
class BuildsController < ApplicationController
  EXTERNAL_BUILD_ATTRIBUTES = [:external_url, :external_status, :docker_repo_digest].freeze
  include CurrentProject

  before_action :authorize_resource!
  before_action :rename_deprecated_attributes, only: [:create, :update]
  before_action :enforce_disabled_docker_builds, only: [:new, :create, :build_docker_image]
  before_action :find_build, only: [:show, :build_docker_image, :edit, :update]

  def index
    @builds = scope.order('id desc')
    if search = params[:search]&.except(:time_format)
      if external = search.delete(:external).presence
        @builds =
          case external.to_s
          when "true" then @builds.where.not(external_status: nil)
          when "false" then @builds.where(external_status: nil)
          else raise
          end
      end

      @builds = @builds.where(search.permit(*Build.column_names)) unless search.empty?
    end

    @pagy, @builds = pagy(@builds, page: params[:page], items: 15)

    respond_to do |format|
      format.html
      format.json { render json: {builds: @builds} }
    end
  end

  def new
    @build = scope.new
  end

  def create
    new = false
    saved = false
    external_build_has_digest = false

    Samson::Retry.retry_when_not_unique do
      if registering_external_build? && @build = find_external_build
        external_build_has_digest = @build.docker_repo_digest.present?
        @build.attributes = edit_build_params(validate: false)
      else
        @build = scope.new(new_build_params.merge(creator: current_user))
      end

      new = @build.new_record?
      changed = @build.changed?

      return head :unprocessable_entity if external_build_has_digest && changed
      saved = !changed || @build.save # nothing has changed or save result
    end

    start_docker_build if saved && !registering_external_build?

    status = new ? :created : :ok
    respond_to_save saved, status, :new
  end

  def show
    @project = @build.project
  end

  def edit
  end

  def update
    success = @build.update_attributes(edit_build_params(validate: true))
    respond_to_save success, :ok, :edit
  end

  def build_docker_image
    start_docker_build
    respond_to do |format|
      format.html do
        redirect_to [current_project, @build]
      end

      format.json do
        render json: {}, status: :ok
      end
    end
  end

  private

  def find_external_build
    build_params = params.require(:build)
    scope = Build.where(git_sha: build_params.require(:git_sha))
    if image_name = build_params[:image_name].presence
      scope.where(image_name: image_name)
    else
      scope.where(dockerfile: build_params.require(:dockerfile))
    end.first
  end

  def find_build
    @build = Build.find(params[:id])
  end

  def rename_deprecated_attributes
    return unless build = params[:build]
    return unless source_url = build.delete(:source_url)
    build[:external_url] = source_url
  end

  def new_build_params
    build_params = params.require(:build)
    build_params.delete(:external_id) # deprecated old attribute
    build_params.permit(
      :git_ref, :name, :description, :dockerfile, :image_name, :docker_repo_digest, :git_sha,
      :external_status, :external_url,
      *Samson::Hooks.fire(:build_permitted_params)
    )
  end

  def edit_build_params(validate:)
    build_params = params.require(:build)
    build_params.delete(:external_id) # deprecated old attribute
    allowed = [:name, :description, :external_status, :external_url]
    allowed << :docker_repo_digest unless @build.docker_repo_digest # can update external build to set digest
    if validate
      build_params.permit(*allowed)
    else
      build_params.to_unsafe_h.slice(*allowed)
    end
  end

  def start_docker_build
    DockerBuilderService.new(@build).run
  end

  def respond_to_save(saved, status, template)
    respond_to do |format|
      format.html do
        if saved
          redirect_to [current_project, @build]
        else
          render template, status: :unprocessable_entity
        end
      end

      format.json do
        if saved
          render json: {}, status: status
        else
          render_json_error 422, @build.errors # same as json_exceptions.rb
        end
      end
    end
  end

  def enforce_disabled_docker_builds
    return if !@project.docker_image_building_disabled? || registering_external_build?
    redirect_to project_builds_path(@project), alert: "Image building is disabled, they must be created via the api."
  end

  def registering_external_build?
    return @registering_external_build if defined?(@registering_external_build)
    @registering_external_build = (
      action_name == "create" &&
      EXTERNAL_BUILD_ATTRIBUTES.any? { |e| params.dig(:build, e).present? }
    )
  end

  def scope
    current_project&.builds || Build.where(nil)
  end
end
