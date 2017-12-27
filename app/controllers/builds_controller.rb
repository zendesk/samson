# frozen_string_literal: true
class BuildsController < ApplicationController
  EXTERNAL_BUILD_ATTRIBUTES = [:external_id, :docker_repo_digest].freeze
  include CurrentProject

  before_action :authorize_resource!
  before_action :rename_deprecated_attributes, only: [:create, :update]
  before_action :enforce_disabled_docker_builds, only: [:new, :create, :build_docker_image]
  before_action :find_build, only: [:show, :build_docker_image, :edit, :update]

  def index
    @builds = scope.order('id desc').page(page)
    if search = params[:search]&.except(:time_format)
      if external = search.delete(:external).presence
        @builds =
          case external.to_s
          when "true" then @builds.where.not(external_id: nil)
          when "false" then @builds.where(external_id: nil)
          else raise
          end
      end

      @builds = @builds.where(search.permit(*Build.column_names)) unless search.empty?
    end

    respond_to do |format|
      format.html
      format.json { render json: {builds: @builds} }
    end
  end

  def new
    @build = scope.new
  end

  def create
    external_id = params.dig(:build, :external_id).presence
    if external_id && @build = Build.where(external_id: external_id).first
      @build.attributes = edit_build_params(validate: false)
    else
      @build = scope.new(new_build_params.merge(creator: current_user))
    end

    new = @build.new_record?
    saved = @build.save

    start_docker_build if saved && EXTERNAL_BUILD_ATTRIBUTES.all? { |e| @build.public_send(e).blank? }
    respond_to_save saved, (new ? :created : :ok), :new
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

  def find_build
    @build = Build.find(params[:id])
  end

  def rename_deprecated_attributes
    return unless build = params[:build]
    return unless source_url = build.delete(:source_url)
    build[:external_url] = source_url
  end

  def new_build_params
    params.require(:build).permit(
      :git_ref, :name, :description, :dockerfile, :image_name, :docker_repo_digest, :git_sha,
      :external_id, :external_status, :external_url,
      *Samson::Hooks.fire(:build_permitted_params)
    )
  end

  def edit_build_params(validate:)
    attributes = params.require(:build)
    allowed = [:name, :description, :external_status]
    allowed << :docker_repo_digest unless @build.docker_repo_digest # can update external build to set digest
    if validate
      attributes.permit(*allowed)
    else
      attributes.to_unsafe_h.slice(*allowed)
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
    action_name == "create" && EXTERNAL_BUILD_ATTRIBUTES.any? { |e| params.dig(:build, e).present? }
  end

  def scope
    current_project&.builds || Build.where(nil)
  end
end
