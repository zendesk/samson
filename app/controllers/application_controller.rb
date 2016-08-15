# frozen_string_literal: true
require 'doorkeeper_auth'

class ApplicationController < ActionController::Base
  include DoorkeeperAuth
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  force_ssl if: :force_ssl?

  api_accessible! false

  include CurrentUser # must be after protect_from_forgery, so that authenticate! is called

  rescue_from(DoorkeeperAuth::DisallowedAccessError) do |message|
    if Rails.env.test?
      raise(DoorkeeperAuth::DisallowedAccessError, message)
    else
      render text: "This resource is not available via the API", status: 403
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

  def redirect_back_or(fallback)
    if param_location = params[:redirect_to].to_s.presence
      if param_location.is_a?(String) && param_location.start_with?('/')
        redirect_to URI("http://nope.nope#{param_location}").request_uri # using URI to silence Brakeman
      else
        render status: :bad_request, plain: 'Invalid redirect_to parameter'
      end
    elsif request.env['HTTP_REFERER']
      redirect_to :back
    else
      redirect_to fallback
    end
  end
end
