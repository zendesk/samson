# frozen_string_literal: true
class BuildsController < ApplicationController
  include CurrentProject

  before_action :authorize_resource!
  before_action :find_build, only: [:show, :build_docker_image, :edit, :update]

  def index
    @builds = current_project.builds.order('id desc').page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @builds }
    end
  end

  def new
    @build = current_project.builds.build
  end

  def create
    @build = new_or_modified_build
    @build.creator = current_user
    start_docker_build if saved = @build.save
    respond_to_save saved, :created, :new
  end

  def show
    @project = @build.project
  end

  def edit
  end

  def update
    success = @build.update_attributes(edit_build_params)
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

  def new_build_params
    params.require(:build).permit(*Build::ASSIGNABLE_KEYS)
  end

  def edit_build_params
    params.require(:build).permit(:label, :description)
  end

  def start_docker_build
    DockerBuilderService.new(@build).run!(push: true)
  end

  def new_or_modified_build
    if old_build = current_project.builds.where(git_sha: git_sha).last
      old_build.update_attributes(new_build_params)
      old_build
    else
      current_project.builds.build(new_build_params)
    end
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
        render json: {}, status: (saved ? status : :unprocessable_entity)
      end
    end
  end

  def git_sha
    @git_sha ||= begin
      # Create/update local cache to avoid getting a stale reference
      current_project.repository.exclusive(holder: 'BuildsController#create', &:update_local_cache!)
      current_project.repository.commit_from_ref(new_build_params[:git_ref])
    end
  end
end
