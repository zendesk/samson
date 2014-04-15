require 'omniauth/github_authorization'

class SessionsController < ApplicationController
  before_filter :restrict_end_users, only: :zendesk

  skip_before_filter :login_users

  def new
    if logged_in?
      redirect_to root_path
    end
  end

  def github
    login_user(role_id: github_authorization.role_id)
  end

  def zendesk
    login_user(role_id: role_name_to_id(auth_hash.info.role))
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

  def strategy
    request.env['omniauth.strategy']
  end

  def github_authorization
    GithubAuthorization.new(
      auth_hash.extra.raw_info.login,
      strategy.access_token.token
    )
  end

  def redirect_to_origin_or_default
    redirect_to request.env['omniauth.origin'] || root_path
  end

  def restrict_end_users
    if auth_hash.info.role == 'end-user' || auth_hash.info.email.blank?
      flash[:error] = 'You are unauthorized.'
      redirect_to login_path
    end
  end

  def role_name_to_id(role)
    if role == 'admin'
      Role::ADMIN.id
    else
      Role::VIEWER.id
    end
  end

  def login_user(options = {})
    user = User.create_or_update_from_hash(options.merge(
      external_id: "#{strategy.name}-#{auth_hash.uid}",
      name: auth_hash.info.name,
      email: auth_hash.info.email
    ))

    if user.persisted?
      self.current_user = user
      flash[:notice] = "You have been logged in."
    else
      flash[:error] = "Could not log you in."
    end

    redirect_to_origin_or_default
  end
end
