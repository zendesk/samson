# frozen_string_literal: true
class DeployNotificationsChannel < ActionCable::Channel::Base
  def self.broadcast(count)
    ActionCable.server.broadcast(channel_name, {count: count})
  end

  # called when using javascript App.cable.subscriptions.create
  def subscribed
    stream_from channel_name
  end

  # called when user navigates away or closes tab
  def unsubscribed
    stop_all_streams
  end
end
