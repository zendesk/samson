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
    message = "You are not authorized to view this page."
    respond_to do |format|
      format.json do
        render json: {error: message}, status: :unauthorized
      end
      format.html do
        flash[:authorization_error] = message
        redirect_back_or(login_path)
      end
    end
  end

  private

  def redirect_back_or(path)
    redirect_back fallback_location: path
  end
end
