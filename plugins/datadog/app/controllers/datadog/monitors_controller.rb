# frozen_string_literal: true

class Datadog::MonitorsController < ApplicationController
  def index
    @stage = Stage.find(params.fetch(:id))
    render "samson_datadog/_monitor_list", layout: false
  end
end
