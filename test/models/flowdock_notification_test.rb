require 'test_helper'

describe FlowdockNotification do
  it "notifies all Flowdock flows configured for the stage" do
    project = stub(name: "Glitter")
    user = stub(name: "John Wu", email: "wu@rocks.com")
    stage = stub(name: "staging", flowdock_tokens: ["x123yx"], project: project)
    deploy = stub(summary: "hello world!", user: user)

    notification = FlowdockNotification.new(stage, deploy)

    endpoint = "https://api.flowdock.com/v1/messages/team_inbox/x123yx"
    delivery = stub_request(:post, endpoint)

    notification.deliver

    assert_requested delivery
  end
end
