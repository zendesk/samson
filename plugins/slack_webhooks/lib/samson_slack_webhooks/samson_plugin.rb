# frozen_string_literal: true
require 'faraday'

module SamsonSlackWebhooks
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_slack_webhooks"
Samson::Hooks.view :deploy_view, "samson_slack_webhooks"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_webhooks.build(
    old_stage.slack_webhooks.map { |s| s.attributes.except("id", "created_at", "updated_at") }
  )
end

Samson::Hooks.callback :stage_permitted_params do
  {
    slack_webhooks_attributes: [
      :id, :_destroy,
      :webhook_url, :channel,
      :buddy_box, :buddy_request, :before_deploy, :on_deploy_success, :on_deploy_failure
    ]
  }
end

Samson::Hooks.callback :buddy_request do |deploy|
  url, channel = ENV['SLACK_GLOBAL_BUDDY_REQUEST'].to_s.split('#', 2)
  if url && channel
    hook = SlackWebhook.new(webhook_url: url, channel: channel)
    SlackWebhookNotification.new(deploy, [hook]).deliver(:buddy_request)
  end
end

[:buddy_request, :before_deploy, :after_deploy].each do |callback|
  Samson::Hooks.callback callback do |deploy, _|
    webhooks = deploy.stage.slack_webhooks.select { |w| w.deliver_for?(callback, deploy) }
    SlackWebhookNotification.new(deploy, webhooks).deliver(callback) if webhooks.any?
  end
end
