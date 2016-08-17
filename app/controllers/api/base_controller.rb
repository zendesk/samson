# frozen_string_literal: true
require 'doorkeeper_auth'

class Api::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token

  before_action :require_project

  include DoorkeeperAuth

  api_accessible! true

  def paginate(scope)
    if scope.is_a?(Array)
      Kaminari.paginate_array(scope).page(page).per(1000)
    else
      scope.page(page)
    end
  end

  def page
    params.fetch(:page, 1)
  end

  def current_project
    @project
  end

  protected

  def require_project
    @project = (Project.find_by_id(params[:project_id]) if params[:project_id])
  end
end
