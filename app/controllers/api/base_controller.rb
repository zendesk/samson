# frozen_string_literal: true
class Api::BaseController < ApplicationController
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

  def current_project
    @project
  end

  # FIXME: loading project by id is weird
  def require_project
    @project = Project.find(params[:project_id]) if params[:project_id].to_s =~ /\A\d+\z/
  end

  # without json format 404/500 pages are rendered in html and auth will redirect
  # can be tested by turning consider_all_requests_local = false in development
  # and raising an error somewhere ... cannot be tested with an integration test
  def enforce_json_format
    return if request.format == :json
    render_json_error 415, 'JSON only api. Use json extension or set Accept header to application/json'
  end

  # remove web-ui scope
  # @override
  def store_requested_oauth_scope
    super << 'api'
  end
end
