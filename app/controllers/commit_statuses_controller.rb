# frozen_string_literal: true
class CommitStatusesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def show
    commit_status = CommitStatus.new(current_project.github_repo, params[:ref])
    render json: { status: commit_status.status, status_list: commit_status.status_list }
  end
end
