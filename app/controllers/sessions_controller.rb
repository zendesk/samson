class SessionsController < ApplicationController
  skip_before_filter :login_users

  def new
    if logged_in?
      redirect_to root_path
    else
      redirect_to '/auth/zendesk'
    end
  end

  def create
    user = User.find_or_create_from_auth_hash(auth_hash)

    if user
      self.current_user = user
      flash[:notice] = "You have been logged in."
    else
      flash[:error] = "Could not log you in."
    end

    redirect_to root_path
  end

  def destroy
    logout!
    flash[:notice] = "You have been logged out."

    redirect_to root_path
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end
end
