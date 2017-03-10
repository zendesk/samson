# frozen_string_literal: true
class ReleaseService
  def initialize(project)
    @project = project
  end

  def release!(attrs = {})
    release = @project.releases.create(attrs)
    if release.persisted?
      push_tag_to_git_repository(release)
      start_deploys(release)
    end
    release
  end

  def can_release?
    GITHUB.repo(@project.user_repo_part).permissions[:push]
  rescue Octokit::NotFound, Octokit::Unauthorized
    false
  end

  private

  def push_tag_to_git_repository(release)
    GITHUB.create_release(@project.github_repo, release.version, target_commitish: release.commit)
  end

  def start_deploys(release)
    deploy_service = DeployService.new(release.author)

    @project.stages.deployed_on_release.each do |stage|
      if Samson::Hooks.fire(:release_deploy_conditions, stage, release).all?
        deploy_service.deploy!(stage, reference: release.version)
      end
    end
  end
end
