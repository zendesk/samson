class ReleaseService
  def initialize(project)
    @project = project
  end

  def create_release(attrs = {})
    release = @project.create_release(attrs)

    if release.persisted?
      project = release.project

      command = <<-SH
        git tag -f #{release.version} #{release.commit}
        git push #{project.repository_url} #{release.version}
      SH

      job = @project.jobs.create!(user: release.author, command: command)
      job_execution = JobExecution.start_job(release.commit, job)
      job_execution.wait!
    end

    release
  end
end
