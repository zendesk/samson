# frozen_string_literal: true
class ApplicationController < ActionController::Base
  before_action :store_requested_oauth_scope

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, unless: :using_per_request_auth?

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  force_ssl if: :force_ssl?

  include CurrentUser # must be after protect_from_forgery, so that authenticate! is called
  include JsonExceptions
  include JsonRenderer
  include JsonPagination
  include Pagy::Backend

  # show error details to users and do not bother ExceptionNotifier
  rescue_from Samson::Hooks::UserError do |exception|
    if request.format.json?
      render_json_error 400, exception.message
    else
      render status: 400, plain: exception.message
    end
  end

  protected

  def force_ssl?
    ENV['FORCE_SSL'] == '1'
  end

  def verified_request?
    warden.winning_strategy || super
  end

  # Get parameters for lograge
  def append_info_to_payload(payload)
    super
    payload["params"] = request.params
  end

  def redirect_back(**options)
    if back = redirect_to_from_params
      redirect_to back, options
    else
      super
    end
  end

  def redirect_to_from_params
    return unless param_location = params[:redirect_to].presence
    if !param_location.is_a?(String) || !param_location.start_with?('/')
      raise "Invalid redirect_to parameter #{param_location}"
    end
    URI("http://ignor.ed#{param_location}").request_uri # using URI to silence Brakeman
  end

  def store_requested_oauth_scope
    request.env['requested_oauth_scopes'] = ['default', controller_name]
  end

  def using_per_request_auth?
    return unless warden = request.env['warden']
    warden.authenticate # trigger auth so we see which strategy won

    [
      Warden::Strategies::Doorkeeper
    ].include? warden.winning_strategy.class
  end
end
