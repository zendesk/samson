class ReleaseTagger
  Error = Class.new(StandardError)
  InvalidCommit = Class.new(Error)

  def initialize(project)
    @project = project
  end

  def tag_release!(release)
    command = <<-SH
      git tag -f #{release.version} #{release.commit}
      git push #{@project.repository_url} #{release.version}
    SH

    job = @project.jobs.create!(user: release.author, command: command)
    job_execution = JobExecution.start_job(release.commit, job)
    job_execution.wait!

    if job.failed?
      if invalid_commit?(release.commit, job.output)
        raise InvalidCommit, "invalid commit `#{release.commit}`"
      else
        raise Error, "unknown error:\n\n#{job.output}"
      end
    end
  end

  private

  def invalid_commit?(commit, output)
    output.include?("pathspec '#{commit}' did not match any file(s) known to git")
  end
end
