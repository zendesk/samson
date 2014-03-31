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
    command = <<-SH
      git tag -f #{release.version} #{release.commit}
      git push #{@project.repository_url} #{release.version}
    SH

    job = @project.jobs.create!(user: release.author, command: command)
    job_execution = JobExecution.start_job(release.commit, job)
    job_execution.wait!
  end

  def start_deploys(release)
    deploy_service = DeployService.new(@project, release.author)

    @project.auto_release_stages.each do |stage|
      deploy_service.deploy!(stage, release.version)
    end
  end
end
