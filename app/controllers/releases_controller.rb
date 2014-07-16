class ReleasesController < ApplicationController
  before_filter :find_project
  before_filter :authorize_deployer!, except: [:show, :index]

  def show
    @release = @project.releases.find_by_version(params[:id])
    @changeset = @project.changeset_for_release(@release)
  end

  def index
    @stages = @project.stages
    @releases = @project.releases.sort_by_version.page(params[:page])

    respond_to do |format|
      format.json { render json: @releases.map(&:version), root: false }
      format.html
    end
  end

  def new
    @release = @project.build_release
  end

  def create
    @release = ReleaseService.new(@project).create_release(release_params)

    redirect_to project_release_path(@project, @release)
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def release_params
    params.require(:release).permit(:commit, :version).merge(author: current_user)
  end
end
