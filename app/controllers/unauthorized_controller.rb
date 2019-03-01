# frozen_string_literal: true
class UnauthorizedController < ActionController::Metal
  include ActionController::UrlFor
  include ActionController::Redirecting

  include AbstractController::Rendering
  include ActionController::Rendering
  include ActionController::Renderers::All
  include ActionController::ConditionalGet
  include ActionController::MimeResponds

  include Rails.application.routes.url_helpers

  delegate :flash, to: :request

  def self.call(env)
    action(:respond).call(env)
  end

  def respond
    message = "You are not #{request.env['warden']&.user ? "authorized to view this page" : "logged in"}"
    respond_to do |format|
      format.json do
        render json: {error: message + ", see docs/api.md on how to authenticate"}, status: :unauthorized
      end
      format.html do
        flash[:authorization_error] = message
        attempted_path = "/#{url_for(params).split("/", 4).last}" # request.fullpath is /unauthenticated
        redirect_to login_path(redirect_to: attempted_path)
      end
    end
  end
end
