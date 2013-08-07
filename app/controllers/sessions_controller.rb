class SessionsController < ApplicationController
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
    else
      # error
    end

    redirect_to root_path
  end

  def destroy
    logout!

    redirect_to root_path
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end
end
