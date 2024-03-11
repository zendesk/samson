# frozen_string_literal: true
require 'omniauth/github_authorization'

class SessionsController < ApplicationController
  skip_before_action :login_user
  skip_before_action :verify_authenticity_token, only: [:ldap]

  def new
    redirect_to root_path if current_user
  end

  def github
    return show_login_restriction unless role_id = github_authorization.role_id
    login(role_id: custom_role_or_default(role_id), github_username: github_authorization.login)
  end

  def google
    return show_login_restriction unless allowed_to_login
    login(role_id: custom_role_or_default(Role::VIEWER.id))
  end

  def ldap
    return show_login_restriction unless allowed_to_login
    login(role_id: custom_role_or_default(Role::VIEWER.id))
  end

  def gitlab
    return show_login_restriction unless allowed_to_login
    login(role_id: custom_role_or_default(Role::VIEWER.id))
  end

  def bitbucket
    return show_login_restriction unless allowed_to_login
    login(role_id: custom_role_or_default(Role::VIEWER.id))
  end

  def failure
    flash[:alert] = "Could not log you in."
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

    flash[:alert] = "Only #{restricted_email_domain} users are allowed to login"
    render :new
  end

  def allowed_to_login
    return false if request.env["omniauth.auth"].nil?
    if restricted_email_domain
      return request.env["omniauth.auth"]["info"]["email"].end_with?("@#{restricted_email_domain}")
    end
    true
  end

  def auth_hash
    request.env['omniauth.auth']
  end

  def restricted_email_domain
    ENV["EMAIL_DOMAIN"]
  end

  def strategy
    request.env['omniauth.strategy']
  end

  def github_authorization
    Omniauth::GithubAuthorization.new(
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
    if auth_hash.provider == 'ldap' && ENV['AUTH_LDAP'] && ENV['USE_LDAP_UID_AS_EXTERNAL_ID']
      uid_field = Rails.application.config.samson.ldap.uid
      uid = auth_hash.extra.raw_info.send(uid_field).presence || raise
      uid = Array(uid).first
    else
      uid = auth_hash.uid
    end

    user = find_or_create_user_from_hash(
      options.merge(
        external_id: "#{strategy.name}-#{uid}",
        name: auth_hash.info.name,
        email: auth_hash.info.email
      )
    )

    if user.persisted?
      self.current_user = user
      user.update_column(:last_login_at, Time.now)
      flash[:notice] = "You have been logged in."
    else
      flash[:alert] = "Could not log you in."
    end

    redirect_to_origin_or_default
  end

  def find_or_create_user_from_hash(hash)
    # first user will be promoted to super admin
    hash[:role_id] = Role::SUPER_ADMIN.id unless User.where.not(email: 'seed@example.com').exists?

    User.create_with(hash).find_or_create_by(external_id: hash[:external_id].to_s)
  end

  def custom_role_or_default(default)
    Integer(ENV.fetch('DEFAULT_USER_ROLE', default))
  end
end
