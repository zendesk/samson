class DeployService
  attr_reader :project, :user

  def initialize(project, user)
    @project, @user = project, user
  end

  def deploy!(stage, reference)
    job = project.jobs.create!(user: user, command: stage.command)
    deploy = stage.deploys.create!(reference: reference, job: job)

    send_before_notifications(stage, deploy)

    job_execution = JobExecution.start_job(reference, job)

    job_execution.subscribe do |_|
      send_after_notifications(stage, deploy)
    end

    deploy
  end

  private

  def send_before_notifications(stage, deploy)
    send_flowdock_notification(stage, deploy)
  end

  def send_after_notifications(stage, deploy)
    if stage.send_email_notifications?
      DeployMailer.deploy_email(stage, deploy).deliver
    end

    send_flowdock_notification(stage, deploy)
  end

  def send_flowdock_notification(stage, deploy)
    if stage.send_flowdock_notifications?
      FlowdockNotification.new(stage, deploy).deliver
    end
  end
end
