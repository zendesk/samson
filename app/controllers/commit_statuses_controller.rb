# frozen_string_literal: true
class CommitStatusesController < ApplicationController
  include CurrentProject

  before_action :authorize_project_deployer!

  def show
    stage = current_project.stages.find_by_permalink!(params.require(:stage_id))
    commit_status = CommitStatus.new(stage.project, params.require(:ref), stage: stage)
    statuses = commit_status.statuses
    # strip dangerous tags so we can safely display as html in ref_status_typeahead.js
    statuses.each do |status|
      [:context, :description].each do |key|
        status[key] = ActionController::Base.helpers.strip_tags(status[key]) if status[key]
      end
    end
    render json: {state: commit_status.state, statuses: statuses}
  end
end
