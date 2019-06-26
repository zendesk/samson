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
          select(&:fail_deploy_on_alert?).
          flat_map(&:monitors).
          reject(&:alert?)
    end

    def validate_deploy(deploy, job_execution)
      # not logging anything for common cases to reduce spam
      return true unless deploy.succeeded?
      return true unless deploy.datadog_monitors_for_validation&.any?

      unless alerting = deploy.datadog_monitors_for_validation.each(&:reload).select(&:alert?).presence
        job_execution.output.puts "No datadog monitors alerting"
        return true
      end

      job_execution.output.puts "Alert on datadog monitors:\n#{alerting.map { |m| "#{m.name} #{m.url}" }.join("\n")}"
      false # mark deploy as failed
    end
  end
end

Samson::Hooks.view :stage_form, "samson_datadog"
Samson::Hooks.view :stage_show, "samson_datadog"

Samson::Hooks.callback :stage_permitted_params do
  [
    :datadog_tags,
    {datadog_monitor_queries_attributes: [:query, :fail_deploy_on_alert, :_destroy, :id]}
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
