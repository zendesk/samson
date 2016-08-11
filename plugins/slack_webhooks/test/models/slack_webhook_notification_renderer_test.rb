# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SlackWebhookNotificationRenderer do
  it "renders a nicely formatted notification" do
    changeset = stub("changeset")
    deploy = stub("deploy", short_reference: "xyz", changeset: changeset, url: "http://sams.on/url")

    changeset.stubs(:commits).returns(stub("commits", count: 3))
    changeset.stubs(:github_url).returns("https://github.com/url")
    changeset.stubs(:pull_requests).returns(stub("pull_requests", count: 2))

    author1 = "author1"
    author2 = "author2"
    changeset.stubs(:author_names).returns([author1, author2])

    subject = "Deploy starting"

    result = SlackWebhookNotificationRenderer.render(deploy, subject)

    result.must_equal <<-RESULT.strip_heredoc.chomp
      :point_right: *Deploy starting* (<http://sams.on/url|view the deploy>) :point_left:
      _<https://github.com/url|3 commits> and 2 pull requests by author1 and author2._
    RESULT
  end
end
