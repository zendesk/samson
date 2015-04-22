class DeployService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def deploy!(stage, reference)
    deploy = stage.create_deploy(reference: reference, user: user)
    SseRailsEngine.send_event('deploys', { type: 'new' })

    if deploy.persisted? && (!stage.deploy_requires_approval? || release_approved?(deploy))
      confirm_deploy!(deploy)
    end

    deploy
  end

  def confirm_deploy!(deploy)
    send_before_notifications(deploy)

    job_execution = JobExecution.start_job(deploy.reference, deploy.job)

    job_execution.subscribe do
      send_after_notifications(deploy)
    end
  end

  def stop!(deploy)
    deploy.stop!
    SseRailsEngine.send_event('deploys', { type: 'finish' })
  end

  private

  def latest_approved_deploy(reference, project)
    Deploy.where(reference: reference).where('buddy_id is NOT NULL AND started_at > ?', BuddyCheck.period.hours.ago)
      .includes(:stage)
      .where(stages: {project_id: project})
      .detect { |d| d.production? && !d.bypassed_approval? }
  end

  def release_approved?(deploy)
    last_deploy = latest_approved_deploy(deploy.reference, deploy.stage.project)

    return false unless last_deploy

    deploy.buddy = (last_deploy.buddy == @user ? last_deploy.job.user : last_deploy.buddy)
    deploy.started_at = Time.now
    deploy.save!

    true
  end

  def send_before_notifications(deploy)
    Samson::Hooks.fire(:before_deploy, deploy, deploy.buddy)

    if deploy.bypassed_approval?
      DeployMailer.bypass_email(deploy, user).deliver_now
    end

    create_github_deployment(deploy)
  end

  def send_after_notifications(deploy)
    Samson::Hooks.fire(:after_deploy, deploy, deploy.buddy)
    SseRailsEngine.send_event('deploys', { type: 'finish' })
    send_deploy_email(deploy)
    send_failed_deploy_email(deploy)
    send_datadog_notification(deploy)
    send_github_notification(deploy)
    update_github_deployment_status(deploy)
  end

  def send_deploy_email(deploy)
    if deploy.stage.send_email_notifications?
      DeployMailer.deploy_email(deploy).deliver_now
    end
  end

  def send_failed_deploy_email(deploy)
    emails = deploy.stage.automated_failure_emails(deploy)
    if emails
      DeployMailer.deploy_failed_email(deploy, emails).deliver_now
    end
  end

  def send_datadog_notification(deploy)
    if deploy.stage.send_datadog_notifications?
      DatadogNotification.new(deploy).deliver
    end
  end

  def send_github_notification(deploy)
    if deploy.stage.send_github_notifications? && deploy.status == "succeeded"
      GithubNotification.new(deploy).deliver
    end
  end

  def create_github_deployment(deploy)
    if deploy.stage.use_github_deployment_api?
      @deployment = GithubDeployment.new(deploy).create_github_deployment
    end
  end

  def update_github_deployment_status(deploy)
    if deploy.stage.use_github_deployment_api?
      GithubDeployment.new(deploy).update_github_deployment_status(@deployment)
    end
  end
end
