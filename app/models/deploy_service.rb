class DeployService
  attr_reader :project, :stage, :user

  def initialize(project, stage, user)
    @project, @stage, @user = project, stage, user
  end

  def deploy!(commit)
    job = project.jobs.create!(user: user, command: stage.command)
    deploy = stage.deploys.create!(commit: commit, job: job)

    JobExecution.start_job(commit, job)

    deploy
  end
end
