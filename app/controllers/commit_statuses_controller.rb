class CommitStatusesController < ApplicationController

  def show
    authorize! :read, commit_status
    render json: { status: commit_status.status }
  end

  private

  def commit_status
    @commit_status ||= CommitStatus.new(project.github_repo, params[:ref])
  end

  def project
    @project ||= Project.find_by_param!(params[:project_id])
  end
end
