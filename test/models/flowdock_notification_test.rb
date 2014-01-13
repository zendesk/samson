require 'test_helper'

describe FlowdockNotification do
  it "notifies all Flowdock flows configured for the stage" do
    stage = stub(flowdock_tokens: ["x123yx"])
    deploy = stub(summary: "hello world!")

    notification = FlowdockNotification.new(stage, deploy)

    endpoint = "https://api.flowdock.com/v1/messages/team_inbox/x123yx"
    delivery = stub_request(:post, endpoint)

    notification.deliver

    assert_requested delivery
  end
end
