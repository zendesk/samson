class CommitStatusesController < ApplicationController
  rescue_from(ActiveRecord::RecordNotFound) { head :not_found }

  before_filter :authorize_deployer!

  def show
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
