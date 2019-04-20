# frozen_string_literal: true
class DeployService
  extend ::Samson::PerformanceTracer::Tracers
  attr_reader :user

  # TODO: try to initialize with the stage ?
  def initialize(user)
    @user = user
  end

  # Returns
  # - running deploy
  # - pending deploy waiting for approval
  # - new deploy that failed validations
  def deploy(stage, attributes)
    deploy = stage.create_deploy(user, attributes)

    if deploy.persisted?
      send_deploy_update

      if stage.cancel_queued_deploys?
        stage.deploys.pending.prior_to(deploy).for_user(user).each do |deploy|
          deploy.job.cancel(user) if deploy.job.queued? # tiny race condition, might cancel jobs that have just started
        end
      end

      if deploy.waiting_for_buddy? && !copy_approval_from_last_deploy(deploy)
        Samson::Hooks.fire(:buddy_request, deploy)
      else
        confirm_deploy(deploy)
      end
    end

    deploy
  end

  def confirm_deploy(deploy)
    stage = deploy.stage

    job_execution = JobExecution.new(deploy.reference, deploy.job, env: construct_env(stage))
    job_execution.on_start { send_before_notifications(deploy, job_execution) }

    # independent so each one can fail and report errors
    job_execution.on_finish { update_average_deploy_time(deploy) }
    job_execution.on_finish { send_deploy_update finished: true }
    job_execution.on_finish { send_deploy_email(deploy) }
    job_execution.on_finish { send_failed_deploy_email(deploy) }
    job_execution.on_finish { notify_outbound_webhooks(deploy) }
    job_execution.on_finish do
      if deploy.redeploy_previous_when_failed? && deploy.status == "failed"
        redeploy_previous_succeeded(deploy, job_execution.output)
      end
    end
    job_execution.on_finish { Samson::Hooks.fire(:after_deploy, deploy, job_execution) }

    JobQueue.perform_later(job_execution, queue: deploy.job_execution_queue_name)

    send_deploy_update
  end

  private

  def redeploy_previous_succeeded(failed_deploy, output)
    unless previous = failed_deploy.previous_succeeded_deploy
      output.puts("Deploy failed, cannot find any previous succeeded deploy")
      return
    end
    reference = previous.exact_reference
    attributes = Samson::RedeployParams.new(previous).to_hash.merge(
      reference: reference,
      buddy: failed_deploy.buddy, # deploy was approved to be reverted if it fails
      redeploy_previous_when_failed: false # prevent cascading redeploys
    )
    redeploy = deploy(previous.stage, attributes)
    output.puts("Deploy failed, redeploying previously succeeded (#{previous.url} #{reference}) with #{redeploy.url}")
  end

  def update_average_deploy_time(deploy)
    stage = deploy.stage

    old_average = stage.average_deploy_time || 0.00
    number_of_deploys = stage.deploys.size

    new_average = (old_average + ((deploy.duration - old_average) / number_of_deploys))

    stage.update_column(:average_deploy_time, new_average)
  end

  def construct_env(stage)
    env = {STAGE: stage.permalink}

    group_names = stage.deploy_groups.pluck(:env_value).join(" ")
    env[:DEPLOY_GROUPS] = group_names if group_names.present?

    env
  end

  def latest_approved_deploy(reference, project)
    Deploy.where(reference: reference).
      where('buddy_id is NOT NULL AND started_at > ?', Samson::BuddyCheck.grace_period.ago).
      includes(:stage).
      where(stages: {project_id: project}).
      reorder('started_at desc').
      detect { |d| d.production? && !d.bypassed_approval? }
  end

  def copy_approval_from_last_deploy(deploy)
    return false unless last_deploy = latest_approved_deploy(deploy.reference, deploy.stage.project)
    return false if deploy.changeset_to(last_deploy).commits.any?
    return false if stage_script_changed_after?(last_deploy)

    deploy.buddy = (last_deploy.buddy == @user ? last_deploy.job.user : last_deploy.buddy)
    deploy.started_at = Time.now
    deploy.save!

    true
  end

  def stage_script_changed_after?(deploy)
    deploy.stage.audits.where("created_at > ?", deploy.started_at).
      any? { |a| a.audited_changes&.key?("script") }
  end

  def send_before_notifications(deploy, job_execution)
    Samson::Hooks.fire(:before_deploy, deploy, job_execution)

    if deploy.bypassed_approval?
      DeployMailer.bypass_email(deploy, user).deliver_now
    end
  end
  add_tracer :send_before_notifications

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

  def notify_outbound_webhooks(deploy)
    deploy.stage.outbound_webhooks.each { |webhook| webhook.deliver(deploy) }
  end

  def send_deploy_update(finished: false)
    count = Deploy.active_count
    count -= 1 if finished # deploy is still active, so we substract one
    DeployNotificationsChannel.broadcast(count)
  end
end
