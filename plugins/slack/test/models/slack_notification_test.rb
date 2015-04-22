require_relative '../test_helper'

describe SlackNotification do
  let(:project) { stub(name: "Glitter") }
  let(:user) { stub(name: "John Wu", email: "wu@rocks.com") }
  let(:stage) { stub(name: "staging", slack_channels: [stub(channel_id: "x123yx")], project: project) }
  let(:deploy) { stub(summary: "hello world!", user: user, stage: stage) }
  let(:notification) { SlackNotification.new(deploy) }
  let(:endpoint) { "https://slack.com/api/chat.postMessage" }

  before do
    SlackNotificationRenderer.stubs(:render).returns("foo")
  end

  it "notifies slack channels configured for the stage" do
    delivery = stub_request(:post, endpoint)
    notification.deliver

    assert_requested delivery
  end

  it "renders a nicely formatted notification" do
    stub_request(:post, endpoint)
    SlackNotificationRenderer.stubs(:render).returns("bar")
    notification.deliver

    content = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      content = body.fetch("text")
    end

    content.must_equal "bar"
  end
end
