class ReleasesController < ApplicationController
  before_filter :find_project

  def show
    @release = @project.releases.find(params[:id])
    @changeset = @project.changeset_for_release(@release)
  end

  def index
    @releases = @project.releases.sort_by_newest
  end

  def new
    @release = @project.releases.build
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
    params.require(:release).permit(:commit).merge(author: current_user)
  end
end
