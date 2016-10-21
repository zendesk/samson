# frozen_string_literal: true
class Api::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :using_per_request_auth?

  before_action :require_project

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

  def using_per_request_auth?
    [
      Warden::Strategies::BasicStrategy::KEY,
      Warden::Strategies::Doorkeeper::KEY
    ].include? request.env['warden']&.winning_strategy
  end
end
