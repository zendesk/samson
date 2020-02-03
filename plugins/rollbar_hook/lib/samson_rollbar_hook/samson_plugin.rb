# frozen_string_literal: true
module SamsonRollbarHook
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, 'samson_rollbar'

Samson::Hooks.callback :stage_permitted_params do
  {
    rollbar_webhooks_attributes: [
      :id, :_destroy,
      :webhook_url, :access_token, :environment
    ]
  }
end

Samson::Hooks.callback :after_deploy do |deploy, _|
  deploy.stage.rollbar_webhooks.each do |webhook|
    key_resolver = Samson::Secrets::KeyResolver.new(webhook.stage.project, [])
    RollbarNotification.new(
      webhook_url: webhook.webhook_url,
      access_token: key_resolver.resolved_attribute(webhook.access_token),
      environment: webhook.environment,
      revision: deploy.reference
    ).deliver
  end
end

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.rollbar_webhooks.build(
    old_stage.rollbar_webhooks.map { |s| s.attributes.except("id", "created_at", "updated_at") }
  )
end
