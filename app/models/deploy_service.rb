class DeployService
  attr_reader :project, :user

  def initialize(project, user)
    @project, @user = project, user
  end

  def deploy!(stage, reference)
    deploy = stage.create_deploy(reference: reference, user: user)

    if deploy.persisted? && (auto_confirm?(stage) || release_approved?(deploy))
      confirm_deploy!(deploy, stage, reference, deploy.buddy)
    end

    deploy
  end

  def confirm_deploy!(deploy, stage, reference, buddy = nil)
    send_before_notifications(stage, deploy, buddy)

    job_execution = JobExecution.start_job(reference, deploy.job)

    job_execution.subscribe do
      send_after_notifications(stage, deploy)
    end
  end

  private

  def auto_confirm?(stage)
    !BuddyCheck.enabled? || !stage.production?
  end

  def latest_approved_deploy(reference, project)
    deploy = nil
    Deploy.where(reference: reference).where(' buddy_id is NOT NULL AND started_at > ?', BuddyCheck.period.hours.ago)
      .includes(:stage)
      .where(stages: {project_id: project, production: true})
      .each do |d|
        next if bypassed?(d.stage, d, d.buddy)
        deploy = d
        break
      end
      deploy
  end

  def release_approved?(deploy)
    last_d = latest_approved_deploy(deploy.reference, deploy.stage.project)

    return false if !last_d

    deploy.buddy = (last_d.buddy == @user ? last_d.job.user : last_d.buddy)
    deploy.update_attributes!({started_at: Time.now, buddy_id: deploy.buddy.id})

    return true
  end

  def send_before_notifications(stage, deploy, buddy)
    send_flowdock_notification(stage, deploy)

    if bypassed?(stage, deploy, buddy)
      DeployMailer.bypass_email(stage, deploy, user).deliver_now
    end

    create_github_deployment(stage, deploy)
  end

  def bypassed?(stage, deploy, buddy)
    !auto_confirm?(stage) && buddy == deploy.user
  end

  def send_after_notifications(stage, deploy)
    if stage.send_email_notifications?
      DeployMailer.deploy_email(stage, deploy).deliver_now
    end

    send_flowdock_notification(stage, deploy)
    send_datadog_notification(stage, deploy)
    send_github_notification(stage, deploy)
    send_zendesk_notification(stage, deploy)
    update_github_deployment_status(stage, deploy)
  end

  def send_flowdock_notification(stage, deploy)
    if stage.send_flowdock_notifications?
      FlowdockNotification.new(stage, deploy).deliver_now
    end
  end

  def send_datadog_notification(stage, deploy)
    if stage.send_datadog_notifications?
      DatadogNotification.new(stage, deploy).deliver_now
    end
  end

  def send_github_notification(stage, deploy)
    if stage.send_github_notifications? && deploy.status == "succeeded"
      GithubNotification.new(stage, deploy).deliver_now
    end
  end

  def send_zendesk_notification(stage, deploy)
    if stage.comment_on_zendesk_tickets?
      ZendeskNotification.new(stage, deploy).deliver_now
    end
  end

  def create_github_deployment(stage, deploy)
    if stage.use_github_deployment_api?
      @deployment = GithubDeployment.new(stage, deploy).create_github_deployment
    end
  end

  def update_github_deployment_status(stage, deploy)
    if stage.use_github_deployment_api?
      GithubDeployment.new(stage, deploy).update_github_deployment_status(@deployment)
    end
  end
end
