# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhookNotificationRenderer do
  let(:subject) { 'Deploy starting' }
  let(:changeset) do
    stub "changeset",
      commits: stub("commits", count: 3),
      github_url: "https://github.com/url",
      pull_requests: stub("pull_requests", count: 2),
      author_names: ['author1', 'author2']
  end

  it "renders a nicely formatted notification" do
    deploy = stub("deploy",
      short_reference: "xyz",
      changeset: changeset,
      pending?: true,
      url: "http://sams.on/url")

    result = SlackWebhookNotificationRenderer.render(deploy, subject)

    result.must_equal <<-RESULT.strip_heredoc.chomp
      :stopwatch: *Deploy starting* (<http://sams.on/url|view the deploy>)
      _<https://github.com/url|3 commits> and 2 pull requests by author1 and author2._
    RESULT
  end

  it 'uses a truck emoji for a running deploy' do
    deploy = stub("deploy",
      short_reference: "xyz",
      changeset: changeset,
      pending?: false,
      running?: true,
      url: "http://sams.on/url")

    result = SlackWebhookNotificationRenderer.render(deploy, subject)
    result.must_include ':truck::dash:'
  end

  it 'uses an X emoji for an errored deploy' do
    deploy = stub("deploy",
      short_reference: "xyz",
      changeset: changeset,
      pending?: false,
      running?: false,
      errored?: true,
      url: "http://sams.on/url")

    result = SlackWebhookNotificationRenderer.render(deploy, subject)
    result.must_include ':x:'
  end

  it 'uses an X emoji for a failed deploy' do
    deploy = stub("deploy",
      short_reference: "xyz",
      changeset: changeset,
      pending?: false,
      running?: false,
      errored?: false,
      failed?: true,
      url: "http://sams.on/url")

    result = SlackWebhookNotificationRenderer.render(deploy, subject)
    result.must_include ':x:'
  end

  it 'uses a checkmark emoji for a successful deploy' do
    deploy = stub("deploy",
      short_reference: "xyz",
      changeset: changeset,
      pending?: false,
      running?: false,
      errored?: false,
      failed?: false,
      succeeded?: true,
      url: "http://sams.on/url")

    result = SlackWebhookNotificationRenderer.render(deploy, subject)
    result.must_include ':white_check_mark:'
  end

  it 'omits emoji for any other situation' do
    deploy = stub("deploy",
      short_reference: "xyz",
      changeset: changeset,
      pending?: false,
      running?: false,
      errored?: false,
      failed?: false,
      succeeded?: false,
      url: "http://sams.on/url")

    result = SlackWebhookNotificationRenderer.render(deploy, subject)
    result.wont_match /:.*:/
  end
end
