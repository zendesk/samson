class DeployService
  attr_reader :project, :user

  def initialize(project, user)
    @project, @user = project, user
  end

  def deploy!(stage, commit)
    job = project.jobs.create!(user: user, command: stage.command)
    deploy = stage.deploys.create!(commit: commit, job: job)

    JobExecution.start_job(commit, job)

    deploy
  end
end
