require 'faraday'

module SamsonSlackWebhooks
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_slack_webhooks/fields"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_webhooks.build(
    old_stage.slack_webhooks.map { |s| s.attributes.except("id", "created_at", "updated_at") }
  )
end

Samson::Hooks.callback :stage_permitted_params do
  { slack_webhooks_attributes: [:id, :webhook_url, :channel, :_destroy] }
end

notify = -> (deploy, _buddy) do
  if deploy.stage.send_slack_webhook_notifications?
    SlackWebhookNotification.new(deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
