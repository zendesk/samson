class DeployService
  attr_reader :project, :user

  def initialize(project, user)
    @project, @user = project, user
  end

  def deploy!(stage, reference)
    deploy = stage.create_deploy(reference: reference, user: user)

    if deploy.persisted? && !(BuddyCheck.enabled? && stage.production?)
      confirm_deploy!(deploy, stage, reference)
    end

    deploy
  end

  def confirm_deploy!(deploy, stage, reference, buddy = nil)
    send_before_notifications(stage, deploy, buddy)

    job_execution = JobExecution.start_job(reference, deploy.job)

    job_execution.subscribe do |_|
      send_after_notifications(stage, deploy)
    end
  end

  private

  def send_before_notifications(stage, deploy, buddy)
    send_flowdock_notification(stage, deploy)

    if BuddyCheck.enabled? && buddy == deploy.user
      DeployMailer.bypass_email(stage, deploy, user).deliver
    end
  end

  def send_after_notifications(stage, deploy)
    if stage.send_email_notifications?
      DeployMailer.deploy_email(stage, deploy).deliver
    end

    send_flowdock_notification(stage, deploy)
    send_datadog_notification(stage, deploy)
    send_github_notification(stage, deploy)
  end

  def send_flowdock_notification(stage, deploy)
    if stage.send_flowdock_notifications?
      FlowdockNotification.new(stage, deploy).deliver
    end
  end

  def send_datadog_notification(stage, deploy)
    if stage.send_datadog_notifications?
      DatadogNotification.new(stage, deploy).deliver
    end
  end

  def send_github_notification(stage, deploy)
    if stage.send_github_notifications? && deploy.status == "succeeded"
      GithubNotification.new(stage, deploy).deliver
    end
  end
end
