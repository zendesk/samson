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

    def store_validation_monitors(deploy)
      deploy.datadog_monitors_for_validation =
        deploy.stage.datadog_monitor_queries.
          select(&:failure_behavior?).
          flat_map(&:monitors).
          reject { |m| m.state(deploy.stage.deploy_groups) == "Alert" }
    end

    def validate_deploy(deploy, job_execution)
      # not logging anything for common cases to reduce spam
      return true unless deploy.succeeded?
      return true unless deploy.datadog_monitors_for_validation&.any?

      alerting =
        deploy.datadog_monitors_for_validation.
        each(&:reload_from_api).
        select { |m| m.state(deploy.stage.deploy_groups) == "Alert" }

      if alerting.none?
        job_execution.output.puts "No datadog monitors alerting"
        return true
      end

      job_execution.output.puts "Alert on datadog monitors:\n#{alerting.map { |m| "#{m.name} #{m.url}" }.join("\n")}"

      alerting.each do |monitor|
        case monitor.failure_behavior
        when "redeploy_previous"
          deploy.redeploy_previous_when_failed = true
          job_execution.output.puts "Trying to redeploy previous succeeded deploy"
        when "fail_deploy" then nil # noop
        else raise ArgumentError, "unsupported failure behavior #{monitor}"
        end
      end

      false # mark deploy as failed
    end
  end
end

Samson::Hooks.view :stage_form, "samson_datadog"
Samson::Hooks.view :stage_show, "samson_datadog"

Samson::Hooks.callback :stage_permitted_params do
  [
    :datadog_tags,
    {datadog_monitor_queries_attributes: [:query, :failure_behavior, :match_target, :match_source, :_destroy, :id]}
  ]
end

Samson::Hooks.callback :before_deploy do |deploy, _|
  SamsonDatadog.send_notification(deploy, additional_tags: ['started'], now: true)
  SamsonDatadog.store_validation_monitors(deploy)
end

Samson::Hooks.callback :validate_deploy do |deploy, job_execution|
  SamsonDatadog.validate_deploy(deploy, job_execution)
end

Samson::Hooks.callback :after_deploy do |deploy, _job_execution|
  SamsonDatadog.send_notification(deploy, additional_tags: ['finished'])
end
