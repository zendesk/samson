class ReleasesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!, except: [:show, :index]

  def show
    @release = @project.releases.find_by_version!(params[:id])
    @changeset = @release.changeset
  end

  def index
    @stages = @project.stages
    @releases = @project.releases.sort_by_version.page(params[:page])
  end

  def new
    @release = @project.releases.build
  end

  def create
    @release = ReleaseService.new(@project).create_release!(release_params)
    redirect_to [@project, @release]
  end

  private

  def release_params
    params.require(:release).permit(:commit).merge(author: current_user)
  end
end
