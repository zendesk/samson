# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhookNotification do
  let(:project) { stub(name: "Glitter", to_s: "foo") }
  let(:user) { stub(name: "John Wu", email: "wu@rocks.com") }
  let(:endpoint) { "https://slack.com/api/chat.postMessage" }
  let(:payload) do
    payload = nil
    assert_requested :post, endpoint do |request|
      body = Rack::Utils.parse_query(request.body)
      payload = JSON.parse(body.fetch('payload'))
    end
    payload
  end
  let(:prs) { payload.fetch('attachments')[0].fetch('fields')[0] }
  let(:risks) { payload.fetch('attachments')[0].fetch('fields')[1] }

  def stub_notification(before_deploy: false, after_deploy: true, for_buddy: false, risks: true, prs: true)
    pr_stub = stub(
      url: 'https://github.com/foo/bar/pulls/1',
      number: 1,
      title: 'PR 1',
      risks: risks ? 'abc' : nil
    )
    changeset = stub "changeset"
    changeset.stubs(:pull_requests).returns(prs ? [pr_stub] : [])

    webhook = SlackWebhook.new(
      webhook_url: endpoint,
      before_deploy: before_deploy,
      after_deploy: after_deploy,
      for_buddy: for_buddy
    )
    stage = stub(name: "Staging", slack_webhooks: [webhook], project: project)
    deploy = stub(
      to_s: 123456, summary: "hello world!", user: user, stage: stage, project: project,
      changeset: changeset, reference: '123abc'
    )
    SlackWebhookNotification.new(deploy)
  end

  describe "#deliver" do
    before do
      SlackWebhookNotificationRenderer.stubs(:render).returns("foo")
      @delivery = stub_request(:post, endpoint)
    end

    it "notifies slack channels configured for the stage when the deploy_phase is enabled" do
      stub_notification.deliver :after_deploy # column defaults to true
      assert_requested @delivery
    end

    it "does not notify slack channels configured for the stage when the deploy_phase is disabled" do
      stub_notification.deliver :before_deploy
      assert_not_requested @delivery
    end

    it "renders a notification" do
      stub_notification(before_deploy: true).deliver :before_deploy
      payload.fetch("text").must_equal "foo"
    end

    it "sends buddy request with the specified message" do
      notification = stub_notification(for_buddy: true)
      notification.buddy_request "buddy approval needed"

      payload.fetch('text').must_equal "buddy approval needed"
      payload.fetch('attachments').length.must_equal 1
      prs['title'].must_equal 'PRs'
      prs['value'].must_equal '<https://github.com/foo/bar/pulls/1|#1> - PR 1'
      risks['title'].must_equal 'Risks'
      risks['value'].must_equal "<https://github.com/foo/bar/pulls/1|#1>:\nabc"
    end

    it 'tells the user if there are no PRs' do
      notification = stub_notification(for_buddy: true, prs: false)
      notification.buddy_request "no PRs"
      prs['value'].must_equal '(no PRs)'
      risks['value'].must_equal "(no risks)"
    end

    it 'says if there are no risks' do
      notification = stub_notification(for_buddy: true, risks: false)
      notification.buddy_request "PRs but no risks"
      prs['value'].must_equal '<https://github.com/foo/bar/pulls/1|#1> - PR 1'
      risks['value'].must_equal "(no risks)"
    end

    it "fails silently on error" do
      notification = stub_notification
      stub_request(:post, endpoint).to_timeout
      Rails.logger.expects(:error)
      notification.deliver :after_deploy
    end
  end

  describe "#default_buddy_request_message" do
    it "renders" do
      notification = stub_notification
      message = notification.default_buddy_request_message
      message.must_include ":pray: <!here> _John Wu_ is requesting approval to deploy "\
      "<http://www.test-url.com/projects/foo/deploys/123456|Glitter *123abc* to Staging>."\
    end
  end
end
