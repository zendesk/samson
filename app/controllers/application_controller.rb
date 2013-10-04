class ApplicationController < ActionController::Base
  include CurrentUser

  rescue_from ActionController::ParameterMissing do
    redirect_to root_path
  end

  force_ssl if Rails.env.production?

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper :flash

  protected

  def authorize_admin!
    unauthorized! unless current_user.is_admin?
  end

  def authorize_deployer!
    unauthorized! unless current_user.is_deployer?
  end

  def unauthorized!
    flash[:error] = "You are not authorized to view this page."
    redirect_to root_path
  end
end
