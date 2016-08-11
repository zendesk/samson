# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhookNotification do
  let(:project) { stub(name: "Glitter", to_s: "foo") }
  let(:user) { stub(name: "John Wu", email: "wu@rocks.com") }
  let(:endpoint) { "https://slack.com/api/chat.postMessage" }

  def stub_notification(before_deploy: false, after_deploy: true, for_buddy: false)
    webhook = stub(
      webhook_url: endpoint, channel: nil,
      before_deploy: before_deploy, after_deploy: after_deploy, for_buddy: for_buddy
    )
    stage = stub(name: "Staging", slack_webhooks: [webhook], project: project)
    deploy = stub(
      to_s: 123456, summary: "hello world!", user: user, stage: stage, project: project, reference: '123abc'
    )
    SlackWebhookNotification.new(deploy)
  end

  before do
    SlackWebhookNotificationRenderer.stubs(:render).returns("foo")
  end

  it "notifies slack channels configured for the stage when the deploy_phase is configured" do
    notification = stub_notification
    delivery = stub_request(:post, endpoint)
    notification.deliver :after_deploy

    assert_requested delivery
  end

  it "does not notify slack channels configured for the stage when the deploy_phase is not configured" do
    notification = stub_notification
    delivery = stub_request(:post, endpoint)
    notification.deliver :before_deploy

    assert_not_requested delivery
  end

  it "renders a nicely formatted notification" do
    notification = stub_notification(before_deploy: true)
    stub_request(:post, endpoint)
    SlackWebhookNotificationRenderer.stubs(:render).returns("bar")
    notification.deliver :before_deploy

    content = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      payload = JSON.parse(body.fetch('payload'))
      content = payload.fetch("text")
    end

    content.must_equal "bar"
  end

  it "sends buddy request with the specified message" do
    notification = stub_notification(for_buddy: true)
    stub_request(:post, endpoint)
    notification.buddy_request "buddy approval needed"

    content = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      payload = JSON.parse(body.fetch('payload'))
      content = payload.fetch("text")
    end

    content.must_equal "buddy approval needed"
  end

  it "fails silently on error" do
    notification = stub_notification
    stub_request(:post, endpoint).to_timeout
    Rails.logger.expects(:error)
    notification.deliver :after_deploy
  end

  describe "#default_buddy_request_message" do
    it "renders" do
      notification = stub_notification
      message = notification.default_buddy_request_message
      message.must_include ":pray: <!here> _John Wu_ is requesting approval to deploy Glitter *123abc*"\
        " to Staging.\nReview this deploy: http://www.test-url.com/projects/foo/deploys/123456"
    end
  end
end
