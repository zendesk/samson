require 'github_api'

class SessionsController < ApplicationController
  skip_before_filter :login_users, except: :new

  def new
    redirect_to root_path
  end

  def github
    teams = github_api.orgs.teams.list('zendesk')
    owner_team = find_team(teams, 'owners')
    deploy_team = find_team(teams, 'engineering')

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
end
