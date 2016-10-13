# frozen_string_literal: true
require 'faraday'

module SamsonSlackWebhooks
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_slack_webhooks/fields"
Samson::Hooks.view :deploy_view, "samson_slack_webhooks/notify_buddy_box"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_webhooks.build(
    old_stage.slack_webhooks.map { |s| s.attributes.except("id", "created_at", "updated_at") }
  )
end

Samson::Hooks.callback :stage_permitted_params do
  {
    slack_webhooks_attributes: [
      :id, :webhook_url, :channel, :before_deploy, :after_deploy, :for_buddy, :only_on_failure, :_destroy
    ]
  }
end

[:before_deploy, :after_deploy].each do |callback|
  Samson::Hooks.callback callback do |deploy, _buddy|
    if deploy.stage.send_slack_webhook_notifications? # avoid rendering overhead when disabled
      SlackWebhookNotification.new(deploy).deliver(callback)
    end
  end
end
