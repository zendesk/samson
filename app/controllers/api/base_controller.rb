# frozen_string_literal: true
class Api::BaseController < ApplicationController
  prepend_before_action :enforce_json_format
  before_action :require_project

  # default error has very little information
  # http://stackoverflow.com/questions/33704640/how-to-render-correct-json-format-with-raised-error
  rescue_from ActiveRecord::RecordInvalid do |exception|
    render json: {error: exception.record.errors}, status: 422
  end

  # default error has very little information
  # https://github.com/rails/strong_parameters/issues/157
  rescue_from ActionController::ParameterMissing do |exception|
    render json: {error: {exception.param => ["is required"]}}, status: :bad_request
  end

  # otherwise renders a 500 and goes to airbrake
  # https://coderwall.com/p/ea5vtw/validating-rest-queries-with-rails
  rescue_from ActionController::UnpermittedParameters do |exception|
    details = exception.params.each_with_object({}) { |p, h| h[p] = ["is not permitted"] }
    render json: {error: details}, status: :bad_request
  end

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

  # without json format 404/500 pages are rendered in html and auth will redirect
  # can be tested by turning consider_all_requests_local = false in development
  # and raising an error somewhere ... cannot be tested with an integration test
  def enforce_json_format
    return if request.format == :json
    render status: 415, json: {error: 'JSON only api. Use json extension or set content type application/json'}
  end

  # making sure all scopes are documented
  # @override
  def store_requested_oauth_scope
    scope = controller_name
    raise "Add #{scope} to config/locales/en.yml" unless I18n.t('doorkeeper.applications.help.scopes') =~ /\b#{scope}\b/
    request.env['requested_oauth_scope'] = scope
  end
end
