class CommitStatusesController < ApplicationController
  before_action :authorize_deployer!

  def show
    render json: { status: commit_status.status, status_list: commit_status.status_list }
  end

  private

  def commit_status
    @commit_status ||= CommitStatus.new(project.github_repo, params[:ref])
  end

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
end
