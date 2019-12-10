# frozen_string_literal: true

class Datadog::MonitorsController < ApplicationController
  def index
    @project = Project.find_by_param!(params.require(:project_id))
    if stage_permalink = params[:stage_id]
      @stage = @project.stages.find_by_param!(stage_permalink)
    end

    render "samson_datadog/_monitor_list", layout: false
  end
end
