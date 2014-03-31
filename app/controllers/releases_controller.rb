class ReleasesController < ApplicationController
  before_filter :find_project

  def show
    @release = @project.releases.find(params[:id])
    previous_release_number = @release.number - 1;

    if previous_release_number > 0
      @previous_release = @project.releases.find_by number: previous_release_number
    else
      @previous_release = @release
    end

    @changeset = Changeset.find(@project.github_repo, @release.commit, @previous_release.commit)
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
