# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 7

describe FlowdockNotification do
  let(:deploy) { deploys(:succeeded_test) }
  let(:notification) { FlowdockNotification.new(deploy) }
  let(:endpoint) { "https://api.flowdock.com/v1/messages/team_inbox/x123yx" }
  let(:chat_endpoint) { "https://api.flowdock.com/v1/messages/chat/x123yx" }

  before do
    deploy.stage.stubs(:flowdock_tokens).returns(["x123yx"])
    FlowdockNotificationRenderer.stubs(:render).returns("foo")
  end

  it "sends a buddy request for all Flowdock flows configured for the stage" do
    assert_request(:post, chat_endpoint) do
      notification.buddy_request('test message')
    end
  end

  it "notifies all Flowdock flows configured for the stage" do
    assert_request(:post, endpoint) do
      notification.deliver
    end
  end

  it "renders a nicely formatted notification" do
    assert_request(:post, endpoint, with: ->(r) { r.body.must_include "content=bar" }) do
      FlowdockNotificationRenderer.stubs(:render).returns("bar")
      notification.deliver
    end
  end

  describe "#default_buddy_request_message" do
    it "renders" do
      message = notification.default_buddy_request_message
      message.must_include ":ship: @team Super Admin is requesting approval to deploy Foo **staging** to production"
    end
  end
end
