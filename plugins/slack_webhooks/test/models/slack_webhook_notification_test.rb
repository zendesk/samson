require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe SlackWebhookNotification do
  let(:project) { stub(name: "Glitter") }
  let(:user) { stub(name: "John Wu", email: "wu@rocks.com") }
  let(:endpoint) { "https://slack.com/api/chat.postMessage" }
  let(:webhook) { stub(webhook_url: endpoint, channel: nil) }
  let(:stage) { stub(name: "staging", slack_webhooks: [webhook], project: project) }
  let(:deploy) { stub(summary: "hello world!", user: user, stage: stage) }
  let(:notification) { SlackWebhookNotification.new(deploy) }

  before do
    SlackWebhookNotificationRenderer.stubs(:render).returns("foo")
  end

  it "notifies slack channels configured for the stage" do
    delivery = stub_request(:post, endpoint)
    notification.deliver

    assert_requested delivery
  end

  it "renders a nicely formatted notification" do
    stub_request(:post, endpoint)
    SlackWebhookNotificationRenderer.stubs(:render).returns("bar")
    notification.deliver

    content = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      payload = JSON.parse(body.fetch('payload'))
      content = payload.fetch("text")
    end

    content.must_equal "bar"
  end
end
