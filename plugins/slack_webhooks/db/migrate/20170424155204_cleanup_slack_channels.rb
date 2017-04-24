# frozen_string_literal: true
class CleanupSlackChannels < ActiveRecord::Migration[5.0]
  class SlackWebhook < ActiveRecord::Base
  end

  def up
    SlackWebhook.find_each do |hook|
      if hook.channel.to_s.include?("#")
        hook.update_column(:channel, hook.channel.delete('#'))
      end
    end
  end

  def down
  end
end
