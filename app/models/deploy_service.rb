class DeployService
  attr_reader :project, :user

  def initialize(project, user)
    @project, @user = project, user
  end

  def deploy!(stage, commit)
    job = project.jobs.create!(user: user, command: stage.command)
    deploy = stage.deploys.create!(commit: commit, job: job)

    job_execution = JobExecution.start_job(commit, job)

    job_execution.subscribe do |_|
      send_notifications(stage, deploy)
    end

    deploy
  end

  private

  def send_notifications(stage, deploy)
    if stage.send_email_notifications?
      DeployMailer.deploy_email(stage, deploy).deliver
    end
  end
end
