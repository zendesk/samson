class DeployService
  attr_reader :project, :stage, :user

  def initialize(project, stage, user)
    @project, @stage, @user = project, stage, user
  end

  def deploy!(commit)
    job = project.jobs.create!(user: user, command: stage.command)
    deploy = stage.deploys.create!(commit: commit, job: job)

    job_execution = JobExecution.start_job(commit, job)

    job_execution.add_subscriber do |job|
      send_notifications(deploy, job)
    end

    deploy
  end

  private

  def send_notifications(deploy, job)
    if @stage.send_email_notifications?
      DeployMailer.deploy_email(@stage, deploy, job).deliver
    end
  end
end
