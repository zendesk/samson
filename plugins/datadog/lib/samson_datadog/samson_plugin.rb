# frozen_string_literal: true
module SamsonDatadog
  class Engine < Rails::Engine
  end

  class << self
    def send_notification(deploy, **kwargs)
      if deploy.stage.datadog_tags.present?
        DatadogNotification.new(deploy).deliver(**kwargs)
      end
    end

    def store_rollback_monitors(deploy)
      deploy.datadog_monitors_for_rollback =
        deploy.stage.datadog_monitor_queries.
          select(&:rollback_on_alert?).
          flat_map(&:monitors).
          reject(&:alert?)
    end

    def rollback_deploy(deploy, job_execution)
      # not logging anything to reduce spam, since users did not enable datadog monitors
      return if !deploy.succeeded? || !deploy.datadog_monitors_for_rollback&.any?

      unless alerting = deploy.datadog_monitors_for_rollback.each(&:reload).select(&:alert?).presence
        return job_execution.output.puts "No datadog monitors alerting"
      end

      job_execution.output.puts "Alert on datadog monitors:\n#{alerting.map { |m| "#{m.name} #{m.url}" }.join("\n")}"

      unless previous_deploy = deploy.previous_succeeded_deploy
        return job_execution.output.puts "No previous successful commit for rollback found"
      end

      if previous_deploy.commit == deploy.commit # prevents cascading/useless rollbacks when monitor is always broken
        return job_execution.output.puts "No rollback to #{previous_deploy.exact_reference}, it is the same commit"
      end

      rollback = DeployService.new(deploy.user).redeploy(deploy)

      if rollback.persisted?
        job_execution.output.puts "Triggered rollback to previous commit #{rollback.exact_reference} #{rollback.url}"
      else
        errors = rollback.errors.full_messages.join(", ")
        job_execution.output.puts "Error triggering rollback to previous commit #{rollback.exact_reference} #{errors}"
      end
    end
  end
end

Samson::Hooks.view :stage_form, "samson_datadog"
Samson::Hooks.view :stage_show, "samson_datadog"

Samson::Hooks.callback :stage_permitted_params do
  [
    :datadog_tags,
    {datadog_monitor_queries_attributes: [:query, :rollback_on_alert, :_destroy, :id]}
  ]
end

Samson::Hooks.callback :before_deploy do |deploy, _|
  SamsonDatadog.send_notification(deploy, additional_tags: ['started'], now: true)
  SamsonDatadog.store_rollback_monitors(deploy)
end

Samson::Hooks.callback :after_deploy do |deploy, job_execution|
  SamsonDatadog.send_notification(deploy, additional_tags: ['finished'])
  SamsonDatadog.rollback_deploy(deploy, job_execution)
end
