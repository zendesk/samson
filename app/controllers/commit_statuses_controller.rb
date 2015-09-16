class CommitStatusesController < ApplicationController
  include CurrentProject
  include ProjectLevelAuthorization

  before_action do
    find_project(params[:project_id])
  end

  before_action :authorize_project_deployer!

  def show
    render json: { status: commit_status.status, status_list: commit_status.status_list }
  end

  private

  def commit_status
    @commit_status ||= CommitStatus.new(@project.github_repo, params[:ref])
  end
end
