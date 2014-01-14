require 'github_api'

class SessionsController < ApplicationController
  skip_before_filter :login_users

  def new
    if logged_in?
      redirect_to root_path
    end
  end

  def github
    teams = github_api.orgs.teams.list(github_config.organization)
    owner_team = find_team(teams, github_config.admin_team)
    deploy_team = find_team(teams, github_config.deploy_team)

    role = if team_member?(owner_team)
      Role::ADMIN.id
    elsif team_member?(deploy_team)
      Role::DEPLOYER.id
    else
      Role::VIEWER.id
    end

    user = User.create_or_update_from_hash(
      name: auth_hash.info.name,
      email: auth_hash.info.email,
      current_token: SecureRandom.hex,
      role_id: role
    )

    if user
      self.current_user = user
      flash[:notice] = "You have been logged in."
    else
      flash[:error] = "Could not log you in."
    end

    redirect_to root_path
  end

  def zendesk
    if auth_hash.info.role == "end-user" || auth_hash.info.email.blank?
      flash[:error] = 'You are unauthorized.'
    else
      role_id = if auth_hash.info.role == 'admin'
        Role::ADMIN.id
      else
        Role::VIEWER.id
      end

      user = User.create_or_update_from_hash(
        name: auth_hash.info.name,
        email: auth_hash.info.email,
        role_id: role_id,
        current_token: strategy.access_token.token
      )

      if user
        self.current_user = user
        flash[:notice] = "You have been logged in."
      else
        flash[:error] = "Could not log you in."
      end
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

  def strategy
    request.env['omniauth.strategy']
  end

  def github_api
    @github_api ||= Github.new(oauth_token: strategy.access_token.token)
  end

  def find_team(teams, slug)
    teams.find {|t| t.slug == slug}
  end

  def team_member?(team)
    team && github_api.orgs.teams.team_member?(team.id, github_login)
  end

  def github_login
    auth_hash.extra.raw_info.login
  end

  def github_config
    Rails.application.config.pusher.github
  end
end
