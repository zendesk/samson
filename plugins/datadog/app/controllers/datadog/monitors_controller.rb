# frozen_string_literal: true

class Datadog::MonitorsController < ApplicationController
  def index
    if project_id = params[:project_id]
      @project = Project.find_by_param!(project_id)
    else
      @stage = Stage.find_by_param!(params.fetch(:stage_id))
    end

    render "samson_datadog/_monitor_list", layout: false
  end
end
