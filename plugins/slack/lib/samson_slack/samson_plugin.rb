require 'slack'

module SamsonSlack
  class Engine < Rails::Engine
  end
end
Samson::Hooks.view :stage_form, "samson_slack/fields"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_channels.build(old_stage.slack_channels.map(&:attributes))
end

Samson::Hooks.callback :stage_permitted_params do
  { slack_channels_attributes: [:id, :name, :token, :_destroy] }
end

notify = -> (stage, deploy, _buddy) do
  if stage.send_slack_notifications?
    SlackNotification.new(stage, deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
