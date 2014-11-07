class ReleasesController < ApplicationController
  before_filter :find_project
  before_filter :authorize_deployer!, except: [:show, :index]

  def show
    @release = @project.releases.find_by_version(params[:id])
    @changeset = @project.changeset_for_release(@release)
  end

  def index
    @stages = @project.stages

    if searching_by_date?
      @releases = releases_by_date.page(params[:page])
    else
      @releases = releases.page(params[:page])
    end

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

  def searching_by_date?
    @searching_by_date ||= from.present? && to.present?
  end

  def from
    @from ||= params[:from]
  end

  def to
    @to ||= params[:to]
  end

  def releases
    @project.releases.sort_by_version
  end

  def releases_by_date
    from = Time.parse(params[:from])
    to = Time.parse(params[:to])
    @project.releases.where('created_at BETWEEN ? AND ?', from, to).sort_by_version
  end

  def find_project
    @project = Project.find_by_param!(params[:project_id])
  end

  def release_params
    params.require(:release).permit(:commit).merge(author: current_user)
  end
end
