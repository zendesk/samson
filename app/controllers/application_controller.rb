# frozen_string_literal: true
class ApplicationController < ActionController::Base
  before_action :store_requested_oauth_scope

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, unless: :using_per_request_auth?

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  force_ssl if: :force_ssl?

  include CurrentUser # must be after protect_from_forgery, so that authenticate! is called

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

  def redirect_back_or(fallback, options = {})
    if param_location = params[:redirect_to].presence
      if param_location.is_a?(String) && param_location.start_with?('/')
        redirect_to URI("http://ignor.ed#{param_location}").request_uri, options # using URI to silence Brakeman
        return
      else
        Rails.logger.error("Invalid redirect_to parameter #{param_location}")
      end
    end
    redirect_back options.merge(fallback_location: fallback)
  end

  def store_requested_oauth_scope
    request.env['requested_oauth_scope'] = Warden::Strategies::Doorkeeper::WEB_UI_SCOPE
  end

  def using_per_request_auth?
    return unless warden = request.env['warden']
    warden.authenticate # trigger auth so we see which strategy won

    [
      Warden::Strategies::BasicStrategy,
      Warden::Strategies::Doorkeeper
    ].include? warden.winning_strategy.class
  end
end
