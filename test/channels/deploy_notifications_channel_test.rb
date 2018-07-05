# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployNotificationsChannel do
  describe '.broadcast' do
    it "sends to self" do
      ActionCable.server.expects(:broadcast).with("DeployNotificationsChannel", count: 5)
      DeployNotificationsChannel.broadcast 5
    end
  end

  describe "#subscribed" do
    it "subscribes to self" do
      channel = DeployNotificationsChannel.new stub(identifiers: []), nil
      channel.expects(:stream_from).with("DeployNotificationsChannel")
      channel.subscribed
    end
  end
end
