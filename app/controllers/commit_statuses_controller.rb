class CommitStatusesController < ApplicationController
  include ProjectLevelAuthorization

  before_action :authorize_project_deployer!

  def show
    render json: { status: commit_status.status, status_list: commit_status.status_list }
  end

  private

  def commit_status
    @commit_status ||= CommitStatus.new(current_project.github_repo, params[:ref])
  end
end
