class BuildsController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

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
    @build = create_build
    @build.creator = current_user
    @build.save

    start_docker_build if @build.persisted? && params[:build_image].present?

    respond_to do |format|
      format.html do
        if @build.persisted?
          redirect_to [current_project, @build]
        else
          render :new, status: :unprocessable_entity
        end
      end

      format.json do
        render json: {}, status: (@build.persisted? ? :created : :unprocessable_entity)
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    success = @build.update_attributes(edit_build_params)

    respond_to do |format|
      format.html do
        if success
          redirect_to [current_project, @build]
        else
          render :edit, status: :unprocessable_entity
        end
      end

      format.json do
        render json: {}, status: (success ? :ok : :unprocessable_entity)
      end
    end
  end

  def build_docker_image
    start_docker_build

    respond_to do |format|
      format.html do
        redirect_to [current_project, @build]
      end

      format.json do
        render json: {}, status: 200
      end
    end
  end

  private

  def find_build
    @build = Build.find(params[:id])
  end

  def new_build_params
    params.require(:build).permit(:git_ref, :label, :description)
  end

  def edit_build_params
    params.require(:build).permit(:label, :description)
  end

  def start_docker_build
    DockerBuilderService.new(@build).run!(push: true)
  end

  def create_build
    if old_build = current_project.builds.where(git_sha: git_sha).last
      old_build.update_attributes(new_build_params)
      old_build
    else
      current_project.builds.build(new_build_params)
    end
  end

  def git_sha
    @git_sha ||= begin
      # Create/update local cache to avoid getting a stale reference
      current_project.with_lock(holder: 'BuildsController#create') do
        current_project.repository.update_local_cache!
      end

      current_project.repository.commit_from_ref(new_build_params[:git_ref], length: nil)
    end
  end
end
