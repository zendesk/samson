require 'slack'

module SamsonSlack
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :stage_defined do
  Stage.class_eval do

    cattr_reader(:slack_channels_cache_key) { 'slack-channels-list' }

    has_many :slack_channels
    accepts_nested_attributes_for :slack_channels, allow_destroy: true, reject_if: :no_channel_name?
    validate :channel_exists?
    before_save :update_channel_id

    def send_slack_notifications?
      slack_channels.any?
    end

    def channel_name
      slack_channels.first.try(:name)
    end

    def no_channel_name?(slack_attrs)
      slack_attrs['name'].blank?
    end

    def update_channel_id
      if channel_for(channel_name)
        self.slack_channels.first.channel_id = channel_for(channel_name)['id']
      end
    end

    def channel_exists?
      if channel_name
        errors.add(:slack_channels_name, "was not found") unless channel_for(channel_name)
      end
    end

    def channel_for(name)
      return nil unless name

      response = Rails.cache.fetch(slack_channels_cache_key, expires_in: 5.minutes) do
        Slack.channels_list(exclude_archived: 1)
      end
      response['channels'].select { |c| c['name'] == name }.first
    end
  end
end

Samson::Hooks.view :stage_form, "samson_slack/fields"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_channels.build(old_stage.slack_channels.map(&:attributes))
end

Samson::Hooks.callback :stage_permitted_params do
  {slack_channels_attributes: [:id, :name, :token, :_destroy]}
end

notify = -> (stage, deploy, _buddy) do
  if stage.send_slack_notifications?
    SlackNotification.new(stage, deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
