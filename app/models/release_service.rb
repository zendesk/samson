class ReleaseService
  def initialize(project)
    @project = project
  end

  def create_release(attrs = {})
    release = @project.create_release(attrs)

    if release.persisted?
      push_tag_to_git_repository(release)
      start_deploys(release)
    end

    release
  end

  private

  def push_tag_to_git_repository(release)
    release_tagger = ReleaseTagger.new(@project)
    release_tagger.tag_release!(release)
  end

  def start_deploys(release)
    deploy_service = DeployService.new(@project, release.author)

    @project.auto_release_stages.each do |stage|
      deploy_service.deploy!(stage, release.version)
    end
  end
end
