require 'omniauth/github_authorization'

class SessionsController < ApplicationController
  skip_before_action :login_users
  skip_before_action :verify_authenticity_token, only: [ :ldap ]

  def new
    if logged_in?
      redirect_to root_path
    end
  end

  def github
    return show_login_restriction unless role_id = github_authorization.role_id
    login_user(role_id: role_id)
  end

  def google
    return show_login_restriction unless allowed_to_login
    login_user(role_id: Role::VIEWER.id)
  end

  def ldap
    return show_login_restriction unless allowed_to_login
    login_user(role_id: Role::VIEWER.id)
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

  def show_login_restriction
    logout!

    flash[:error] = "Only #{restricted_email_domain} users are allowed to login"
    render :new
  end

  def allowed_to_login
    return false if request.env["omniauth.auth"].nil?
    if restricted_email_domain
      return request.env["omniauth.auth"]["info"]["email"].end_with?(restricted_email_domain)
    end
    return true
  end

  def auth_hash
    request.env['omniauth.auth']
  end

  def restricted_email_domain
    ENV["GOOGLE_DOMAIN"]
  end

  def strategy
    request.env['omniauth.strategy']
  end

  def github_authorization
    GithubAuthorization.new(
      auth_hash.extra.raw_info.login,
      # Use a global token that can query the org groups. No need to use
      # the logged in user's token here since GithubAuthorization is only
      # doing a lookup and checking group membership.
      ENV['GITHUB_TOKEN']
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
