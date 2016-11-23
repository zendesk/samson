# frozen_string_literal: true
require 'omniauth/github_authorization'

class SessionsController < ApplicationController
  skip_around_action :login_user
  skip_before_action :verify_authenticity_token, only: [:ldap]

  def new
    redirect_to root_path if current_user
  end

  def github
    return show_login_restriction unless role_id = github_authorization.role_id
    login(role_id: role_id)
  end

  def google
    return show_login_restriction unless allowed_to_login
    login(role_id: Role::VIEWER.id)
  end

  def ldap
    return show_login_restriction unless allowed_to_login
    login(role_id: Role::VIEWER.id)
  end

  def gitlab
    return show_login_restriction unless allowed_to_login
    login(role_id: Role::VIEWER.id)
  end

  def failure
    Samson::Hooks.fire(:audit_action, nil, 'Failed login', auth_hash)
    flash[:error] = "Could not log you in."
    redirect_to root_path
  end

  def destroy
    user = current_user # current_user disappears after logout! so can't log using current_user
    logout!

    Samson::Hooks.fire(:audit_action, user, 'logout', :success)
    flash[:notice] = "You have been logged out."
    redirect_to root_path
  end

  protected

  def show_login_restriction
    Samson::Hooks.fire(:audit_action, nil, 'Restricted login', auth_hash)
    logout!

    flash[:error] = "Only #{restricted_email_domain} users are allowed to login"
    render :new
  end

  def allowed_to_login
    return false if request.env["omniauth.auth"].nil?
    if restricted_email_domain
      return request.env["omniauth.auth"]["info"]["email"].end_with?(restricted_email_domain)
    end
    true
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

  def login(options = {})
    user = User.create_or_update_from_hash(options.merge(
      external_id: "#{strategy.name}-#{auth_hash.uid}",
      name: auth_hash.info.name,
      email: auth_hash.info.email
    ))

    if user.persisted?
      self.current_user = user
      user.update_column(:last_login_at, Time.now)
      Samson::Hooks.fire(:audit_action, user, 'Successful login')
      flash[:notice] = "You have been logged in."
    else
      Samson::Hooks.fire(:audit_action, user, 'Failed login', auth_hash)
      flash[:error] = "Could not log you in."
    end

    redirect_to_origin_or_default
  end
end
