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

  def stub_notification(risks: true, prs: true)
    pr = stub(
      "PR",
      url: 'https://github.com/foo/bar/pulls/1',
      number: 1,
      title: 'PR 1',
      risks: risks ? 'abc' : nil
    )
    changeset = stub("Changeset", pull_requests: prs ? [pr] : [], commits: [])
    webhook = SlackWebhook.new(webhook_url: endpoint)
    deploy = deploys(:succeeded_test)
    deploy.stubs(changeset: changeset)
    SlackWebhookNotification.new(deploy, [webhook])
  end

  describe "#deliver" do
    before do
      @delivery = stub_request(:post, endpoint)
    end

    it "renders a notification" do
      SlackWebhookNotification.any_instance.stubs(:deploy_callback_content).returns("foo")
      stub_notification.deliver :before_deploy
      payload.fetch("text").must_equal "foo"
    end

    it "notifies slack channels" do
      stub_notification.deliver :after_deploy
      assert_requested @delivery
    end

    it "sends buddy request with the specified message" do
      notification = stub_notification
      notification.deliver :buddy_box, message: "buddy approval needed"

      payload.fetch('text').must_equal "buddy approval needed"
      payload.fetch('attachments').length.must_equal 1
      prs['title'].must_equal 'PRs'
      prs['value'].must_equal '<https://github.com/foo/bar/pulls/1|#1> - PR 1'
      risks['title'].must_equal 'Risks'
      risks['value'].must_equal "<https://github.com/foo/bar/pulls/1|#1>:\nabc"
    end

    it 'tells the user if there are no PRs' do
      notification = stub_notification(prs: false)
      notification.deliver :buddy_box, message: "no PRs"
      prs['value'].must_equal '(no PRs)'
      risks['value'].must_equal "(no risks)"
    end

    it 'says if there are no risks' do
      notification = stub_notification(risks: false)
      notification.deliver :buddy_box, message: "PRs but no risks"
      prs['value'].must_equal '<https://github.com/foo/bar/pulls/1|#1> - PR 1'
      risks['value'].must_equal "(no risks)"
    end

    it "fails silently when a single webhook fails, but still executes the others" do
      notification = stub_notification
      stub_request(:post, endpoint).to_timeout
      Rails.logger.expects(:error)
      Samson::ErrorNotifier.expects(:notify)
      notification.deliver :after_deploy
    end
  end

  describe "#default_buddy_request_message" do
    it "renders" do
      notification = stub_notification
      message = notification.default_buddy_request_message
      message.must_equal ":ship: <!here> _Super Admin_ is requesting approval to deploy " \
        "<http://www.test-url.com/projects/foo/deploys/178003093|*staging* to Foo / Staging>."
    end
  end

  describe "#deploy_callback_content" do
    def render
      SlackWebhookNotification.new(deploy, []).send(:deploy_callback_content)
    end

    let(:pull_requests) do
      [
        stub("PR one", number: 42, title: 'Fix bug', url: 'http://pr1.url/', users: [stub(login: 'author1')]),
        stub("PR two", number: 43, title: 'Properly fix bug', url: 'http://pr2.url/', users: [stub(login: 'author2')])
      ]
    end
    let(:changeset) do
      stub "changeset",
        commits: stub("commits", count: 3),
        commit_range_url: "https://github.com/url",
        pull_requests: pull_requests,
        author_names: ['author1', 'author2']
    end
    let(:deploy) do
      deploy = deploys(:succeeded_test)
      deploy.stubs(:changeset).returns(changeset)
      deploy.stubs(:url).returns("http://sams.on/url")
      deploy
    end

    it "renders a nicely formatted pending notification" do
      deploy.job.status = "pending"
      render.must_equal <<~TEXT.chomp
        :stopwatch: *[Foo] Super Admin is about to deploy staging to Staging* (<http://sams.on/url|view the deploy>)
        _<https://github.com/url|3 commits> and 2 pull requests by author1 and author2._

        *Pull Requests*

        > PR#42 <http://pr1.url/|Fix bug> (author1)
        > PR#43 <http://pr2.url/|Properly fix bug> (author2)
      TEXT
    end

    it "does not render pull requests for finished deploys" do
      render.must_equal <<~TEXT.chomp
        :white_check_mark: *[Foo] Super Admin deployed staging to Staging* (<http://sams.on/url|view the deploy>)
        _<https://github.com/url|3 commits> and 2 pull requests by author1 and author2._
      TEXT
    end

    it "does not use links with ports that do not work in slack" do
      deploy.stubs(:url).returns("http://sams.on:123/url")
      render.must_include "Staging* (http://sams.on:123/url)"
    end

    it "alerts users when pull requests were not used" do
      deploy.job.status = "pending"
      pull_requests.clear
      render.must_include 'There are commits going live that did not go through a pull request'
    end

    it 'uses a truck emoji for a running deploy' do
      deploy.job.status = "running"
      render.must_include ':truck::dash:'
    end

    it 'uses an X emoji for an errored deploy' do
      deploy.job.status = "errored"
      render.must_include ':x:'
    end

    it 'uses an X emoji for a failed deploy' do
      deploy.job.status = "failed"
      render.must_include ':x:'
    end

    it 'uses a checkmark emoji for a succeeded deploy' do
      render.must_include ':white_check_mark:'
    end

    it 'omits emoji for any other situation' do
      deploy.job.status = "cancelling"
      render.wont_match /:.*:/
    end
  end
end
