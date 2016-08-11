# frozen_string_literal: true
module SamsonDatadog
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_datadog/fields"
Samson::Hooks.view :stage_show, "samson_datadog/show"

Samson::Hooks.callback :stage_permitted_params do
  [
    :datadog_tags,
    :datadog_monitor_ids
  ]
end

Samson::Hooks.callback :after_deploy do |deploy, _buddy|
  if deploy.stage.send_datadog_notifications?
    DatadogNotification.new(deploy).deliver
  end
end
