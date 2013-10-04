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

    if access_token.try(:token)
      token_id = access_token.get('/api/v2/oauth/tokens/current.json').parsed['token']['id']
      access_token.delete("/api/v2/oauth/tokens/#{token_id}.json")
    end

    if user
      self.current_user = user
      flash[:notice] = "You have been logged in."
    else
      flash[:error] = "Could not log you in."
    end

    redirect_to root_path
  end

  def failure
    flash[:error] = "Could not log you in."
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

  def access_token
    request.env['omniauth.strategy'].access_token
  end
end
