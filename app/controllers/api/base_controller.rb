# frozen_string_literal: true
class Api::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :using_per_request_auth?

  prepend_before_action :enforce_json_format
  before_action :require_project

  protected

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

  def require_project
    @project = (Project.find_by_id(params[:project_id]) if params[:project_id])
  end

  def using_per_request_auth?
    [
      Warden::Strategies::BasicStrategy::KEY,
      Warden::Strategies::Doorkeeper::KEY
    ].include? request.env['warden']&.winning_strategy
  end

  # without json format 404/500 pages are rendered in html and auth will redirect
  # can be tested by turning consider_all_requests_local = false in development
  # and raising an error somewhere ... cannot be tested with an integration test
  def enforce_json_format
    return if request.format == :json
    render status: 415, json: {error: 'JSON only api. Use json extension or set content type application/json'}
  end
end
