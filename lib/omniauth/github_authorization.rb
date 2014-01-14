require 'github_api'

class GithubAuthorization
  def initialize(login, token)
    @login = login
    @github = Github.new(oauth_token: token)
  end

  def role_id
    teams = @github.orgs.teams.list(config.organization)
    owner_team = find_team(teams, config.admin_team)
    deploy_team = find_team(teams, config.deploy_team)

    role = if team_member?(owner_team)
      Role::ADMIN.id
    elsif team_member?(deploy_team)
      Role::DEPLOYER.id
    else
      Role::VIEWER.id
    end
  end

  private

  def find_team(teams, slug)
    teams.find {|t| t.slug == slug}
  end

  def team_member?(team)
    team && @github.orgs.teams.team_member?(team.id, @login)
  end

  def config
    Rails.application.config.pusher.github
  end
end
