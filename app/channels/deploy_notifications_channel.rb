# frozen_string_literal: true
class DeployNotificationsChannel < ActionCable::Channel::Base
  def self.broadcast
    ActionCable.server.broadcast name, count: Deploy.active_count
  end

  def subscribed
    stream_from self.class.name
  end
end
