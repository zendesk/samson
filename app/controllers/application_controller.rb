class ApplicationController < ActionController::Base
  rescue_from ActionController::ParameterMissing do
    redirect_to root_path
  end

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Must be after protect_from_forgery, so that authenticate! is called
  include CurrentUser

  helper :flash

  protected

  def verified_request?
    warden.winning_strategy || super
  end

  def authorize_admin!
    unauthorized! unless current_user.is_admin?
  end

  def authorize_deployer!
    unauthorized! unless current_user.is_deployer?
  end

  def unauthorized!
    respond_to do |format|
      format.html do
        begin
          flash[:error] = "You are not authorized to view this page."
          redirect_to :back
        rescue ActionController::RedirectBackError
          redirect_to root_path
        end
      end

      format.json do
        render json: {}, status: 404
      end
    end
  end
end
