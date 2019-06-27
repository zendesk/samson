# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployNotificationsChannel do
  let(:channel) { DeployNotificationsChannel.new stub(identifiers: []), nil }

  describe '.broadcast' do
    it "sends to self" do
      ActionCable.server.expects(:broadcast).with("deploy_notifications", count: 5)
      DeployNotificationsChannel.broadcast 5
    end
  end

  describe "#subscribed" do
    it "subscribes to self" do
      channel.expects(:stream_from).with("deploy_notifications")
      channel.subscribed
    end
  end

  describe "#unsubscribed" do
    it "unsubscribes" do
      channel.expects(:stop_all_streams)
      channel.unsubscribed
    end
  end
end
