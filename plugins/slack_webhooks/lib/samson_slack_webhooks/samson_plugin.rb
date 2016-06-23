require 'faraday'

module SamsonSlackWebhooks
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_slack_webhooks/fields"
Samson::Hooks.view :deploy_view, "shared/notify_buddy_box" do |deploy:, project:|
  {
    deploy: deploy, project: project,
    id_prefix: 'slack',
    send_buddy_request: deploy.stage.send_slack_buddy_request?,
    form_path: AppRoutes.url_helpers.slack_webhooks_notify_path(deploy_id: deploy.id),
    title: 'Request a buddy via Slack',
    message: SlackWebhookNotification.new(deploy).default_buddy_request_message,
    channels: deploy.stage.slack_buddy_channels.join(', '),
    users: SamsonSlackWebhooks::SlackWebhooksService.new.users,
    channel_type: 'channels'
  }
end

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_webhooks.build(
    old_stage.slack_webhooks.map { |s| s.attributes.except("id", "created_at", "updated_at") }
  )
end

Samson::Hooks.callback :stage_permitted_params do
  { slack_webhooks_attributes: [:id, :webhook_url, :channel, :before_deploy, :after_deploy, :for_buddy, :_destroy] }
end

Samson::Hooks.callback :before_deploy do |deploy, _buddy|
  if deploy.stage.send_slack_webhook_notifications?
    SlackWebhookNotification.new(deploy).deliver(:before_deploy)
  end
end

Samson::Hooks.callback :after_deploy do |deploy, _buddy|
  if deploy.stage.send_slack_webhook_notifications?
    SlackWebhookNotification.new(deploy).deliver(:after_deploy)
  end
end
