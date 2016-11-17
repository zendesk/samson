# frozen_string_literal: true
class CommitStatusesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def show
    stage = Stage.find_by_permalink!(params.require(:stage_id))
    commit_status = CommitStatus.new(stage, params[:ref])
    render json: { status: commit_status.status, status_list: commit_status.status_list }
  end
end
