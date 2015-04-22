require_relative '../test_helper'

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
    delivery = stub_request(:post, chat_endpoint)
    notification.buddy_request('test message')

    assert_requested delivery
  end

  it "notifies all Flowdock flows configured for the stage" do
    delivery = stub_request(:post, endpoint)
    notification.deliver

    assert_requested delivery
  end

  it "renders a nicely formatted notification" do
    stub_request(:post, endpoint)
    FlowdockNotificationRenderer.stubs(:render).returns("bar")
    notification.deliver

    content = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      content = body.fetch("content")
    end

    content.must_equal "bar"
  end
end
