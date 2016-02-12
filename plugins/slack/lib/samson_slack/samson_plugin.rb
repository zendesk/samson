require 'slack'

module SamsonSlack
  class Engine < Rails::Engine
  end
end
Samson::Hooks.view :stage_form, "samson_slack/fields"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_channels.build(old_stage.slack_channels.map { |s| s.attributes.except("id", "created_at", "updated_at") })
end

Samson::Hooks.callback :stage_permitted_params do
  { slack_channels_attributes: [:id, :name, :token, :_destroy] }
end

notify = -> (deploy, _buddy) do
  if deploy.stage.send_slack_notifications?
    SlackNotification.new(deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify

if Samson::Hooks.active_plugin?('slack')
  ActiveSupport::Deprecation.warn(<<-EOF)
the existing slack plugin that uses the channels api has been deprecated for a webhook-based one
this plugin will be removed on 3/1/2016, please switch your notifications to webhooks
you can silence this warning by specifying PLUGINS=all,-slack
ref: https://github.com/zendesk/samson/issues/583
  EOF
end
