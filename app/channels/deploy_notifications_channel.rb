# frozen_string_literal: true
class DeployNotificationsChannel < ActionCable::Channel::Base
  def self.broadcast(count)
    ActionCable.server.broadcast name, count: count
  end

  def subscribed
    stream_from self.class.name
  end
end
