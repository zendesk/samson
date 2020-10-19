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
    action = (["patch", "post", "put"].include?(params[:_method]) ? "make this change" : "view this page")
    message = "You are not #{current_user ? "authorized to #{action}" : "logged in"}"
    respond_to do |format|
      format.json do
        render json: {error: "#{message}, see docs/api.md on how to authenticate"}, status: :unauthorized
      end
      format.html do
        attempted_path = "/#{url_for(params).split("/", 4).last}" # request.fullpath is /unauthenticated
        flash[:alert] = "".html_safe << message << ". " << access_request_link
        redirect_to login_path(redirect_to: attempted_path)
      end
    end
  end

  private

  def current_user
    request.env['warden']&.user
  end

  def access_request_link
    return '' if !AccessRequestsController.feature_enabled? || !current_user || current_user.super_admin?
    if current_user.access_request_pending?
      'Access request pending.'
    else
      ActionController::Base.helpers.link_to('Request additional access rights', new_access_request_path)
    end
  end
end
