# frozen_string_literal: true
class GithubAuthorization
  attr_accessor :login

  def initialize(login, token)
    @login = login
    @github = Octokit::Client.new(access_token: token)
  end

  def role_id
    if config.organization
      teams = @github.organization_teams(config.organization)
      owner_team = find_team(teams, config.admin_team)
      deploy_team = find_team(teams, config.deploy_team)

      if team_member?(owner_team)
        Role::ADMIN.id
      elsif team_member?(deploy_team)
        Role::DEPLOYER.id
      elsif organization_member?
        Role::VIEWER.id
      end
    else
      Role::VIEWER.id
    end
  end

  private

  def organization_member?
    @github.organization_member?(config.organization, login)
  end

  def find_team(teams, slug)
    teams.find { |t| t.slug == slug }
  end

  def team_member?(team)
    team && @github.team_member?(team.id, login)
  end

  def config
    Rails.application.config.samson.github
  end
end
