class DeployService
  include ::NewRelic::Agent::MethodTracer
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def deploy!(stage, attributes)
    deploy = stage.create_deploy(user, attributes)

    if deploy.persisted?
      send_sse_deploy_update('new', deploy)

      if !deploy.waiting_for_buddy? || copy_approval_from_last_deploy(deploy)
        confirm_deploy!(deploy)
      end
    end

    deploy
  end

  def confirm_deploy!(deploy)
    send_before_notifications(deploy)

    stage = deploy.stage

    job_execution = JobExecution.new(deploy.reference, deploy.job, construct_env(stage))
    job_execution.on_complete do
      send_after_notifications(deploy)
    end

    JobExecution.start_job(job_execution, key: stage.id)

    send_sse_deploy_update('start', deploy)
  end

  def stop!(deploy)
    deploy.stop!
  end

  private

  def construct_env(stage)
    env = { STAGE: stage.permalink }

    group_names = stage.deploy_groups.pluck(:env_value).sort.join(" ")
    env[:DEPLOY_GROUPS] = group_names if group_names.present?

    env
  end

  def latest_approved_deploy(reference, project)
    Deploy.where(reference: reference).where('buddy_id is NOT NULL AND started_at > ?', BuddyCheck.grace_period.ago)
      .includes(:stage)
      .where(stages: {project_id: project})
      .reorder('started_at desc')
      .detect { |d| d.production? && !d.bypassed_approval? }
  end

  def copy_approval_from_last_deploy(deploy)
    last_deploy = latest_approved_deploy(deploy.reference, deploy.stage.project)
    return false unless last_deploy
    return false if last_deploy.started_at < last_deploy.stage.command_updated_at

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
  add_method_tracer :send_before_notifications

  def send_after_notifications(deploy)
    Samson::Hooks.fire(:after_deploy, deploy, deploy.buddy)
    send_sse_deploy_update('finish', deploy)
    send_deploy_email(deploy)
    send_failed_deploy_email(deploy)
    send_github_notification(deploy)
    update_github_deployment_status(deploy)
  end
  add_method_tracer :send_after_notifications

  def send_deploy_email(deploy)
    if deploy.stage.send_email_notifications?
      DeployMailer.deploy_email(deploy).deliver_now
    end
  end

  def send_failed_deploy_email(deploy)
    if emails = deploy.stage.automated_failure_emails(deploy)
      DeployMailer.deploy_failed_email(deploy, emails).deliver_now
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

  def send_sse_deploy_update(type, deploy)
    SseRailsEngine.send_event('deploys', { type: type, deploy: DeploySerializer.new(deploy, root: nil) })
  end
end
