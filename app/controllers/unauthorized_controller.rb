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
    respond_to do |format|
      format.html do
        flash[:authorization_error] = "You are not authorized to view this page."
        redirect_back_or(login_path)
      end

      format.json do
        render json: {}, status: 404
      end
    end
  end

  private

  def redirect_back_or(path)
    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to path
  end
end
