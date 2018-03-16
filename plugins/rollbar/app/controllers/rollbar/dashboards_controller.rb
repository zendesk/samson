# frozen_string_literal: true

module Rollbar
  class DashboardsController < ApplicationController
    def project
      @project = find_project
    end

    private

    def find_project
      Project.find_by_param!(params.require(:project_id))
    end
  end
end
