# frozen_string_literal: true
class CommitStatusesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def show
    stage = current_project.stages.find_by_permalink!(params.require(:stage_id))
    commit_status = CommitStatus.new(stage.project, params.require(:ref), stage: stage)
    render json: {state: commit_status.state, statuses: commit_status.statuses}
  end
end
