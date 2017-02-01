# frozen_string_literal: true
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
    stage = deploy.stage

    job_execution = JobExecution.new(deploy.reference, deploy.job, construct_env(stage))
    job_execution.on_start do
      send_before_notifications(deploy)
    end
    job_execution.on_complete do
      send_after_notifications(deploy)
    end

    JobExecution.start_job(job_execution, queue: deploy.job_execution_queue_name)

    send_sse_deploy_update('start', deploy)
  end

  private

  def construct_env(stage)
    env = { STAGE: stage.permalink }

    group_names = stage.deploy_groups.sort_by(&:natural_order).map(&:env_value).join(" ")
    env[:DEPLOY_GROUPS] = group_names if group_names.present?

    env
  end

  def latest_approved_deploy(reference, project)
    Deploy.
      joins(:job).
      where(reference: reference).
      where('buddy_id is NOT NULL AND jobs.started_at > ?', BuddyCheck.grace_period.ago).
      joins(:stage).
      where(stages: {project_id: project}).
      reorder('jobs.started_at desc').
      detect { |d| d.production? && !d.bypassed_approval? }
  end

  def copy_approval_from_last_deploy(deploy)
    return false unless last_deploy = latest_approved_deploy(deploy.reference, deploy.stage.project)
    return false if last_deploy.stage.script_updated_after?(last_deploy.started_at)

    deploy.buddy = (last_deploy.buddy == @user ? last_deploy.job.user : last_deploy.buddy)
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
    execute_and_log_errors(deploy) { send_sse_deploy_update('finish', deploy) }
    execute_and_log_errors(deploy) { send_deploy_email(deploy) }
    execute_and_log_errors(deploy) { send_failed_deploy_email(deploy) }
    execute_and_log_errors(deploy) { send_github_notification(deploy) }
    execute_and_log_errors(deploy) { notify_outbound_webhooks(deploy) }
    execute_and_log_errors(deploy) { update_github_deployment_status(deploy) }
  end
  add_method_tracer :send_after_notifications

  # basically does the same as the hooks would do
  def execute_and_log_errors(deploy, &block)
    JobExecutionSubscriber.new(deploy.job, &block).call
  end

  def send_deploy_email(deploy)
    if emails = deploy.stage.notify_email_addresses.presence
      DeployMailer.deploy_email(deploy, emails).deliver_now
    end
  end

  def send_failed_deploy_email(deploy)
    if emails = deploy.stage.automated_failure_emails(deploy)
      DeployMailer.deploy_failed_email(deploy, emails).deliver_now
    end
  end

  def send_github_notification(deploy)
    if deploy.stage.update_github_pull_requests? && deploy.status == "succeeded"
      GithubNotification.new(deploy).deliver
    end
  end

  def notify_outbound_webhooks(deploy)
    deploy.stage.outbound_webhooks.each { |webhook| webhook.deliver(deploy) }
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
    SseRailsEngine.send_event('deploys', type: type, deploy: DeploySerializer.new(deploy, root: nil))
  end
end
