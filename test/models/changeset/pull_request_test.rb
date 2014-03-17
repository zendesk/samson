require 'test_helper'

describe Changeset::PullRequest do
  let(:data) { stub("data", user: user, merged_by: merged_by, body: body) }
  let(:pr) { Changeset::PullRequest.new("xxx", data) }
  let(:user) { stub(login: "foo") }
  let(:merged_by) { stub(login: "bar") }
  let(:body) { "" }

  describe ".find" do
    let(:octokit) { stub("octokit") }

    before do
      Octokit::Client.stubs(:new).returns(octokit)
    end

    it "finds the pull request" do
      octokit.stubs(:pull_request).with("foo/bar", 42).returns(data)
      data.stubs(:title).returns("Make it bigger!")

      pr = Changeset::PullRequest.find("foo/bar", 42)

      pr.title.must_equal "Make it bigger!"
    end

    it "returns nil if the pull request could not be found" do
      octokit.stubs(:pull_request).with("foo/bar", 42).raises(Octokit::NotFound)

      pr = Changeset::PullRequest.find("foo/bar", 42)

      pr.must_be_nil
    end
  end

  describe "#users" do
    it "returns the users associated with the pull request" do
      pr.users.map(&:login).must_equal ["foo", "bar"]
    end

    it "excludes duplicate users" do
      merged_by.stubs(:login).returns("foo")
      pr.users.map(&:login).must_equal ["foo"]
    end
  end

  describe "#jira_issues" do
    it "returns a list of JIRA issues referenced in the PR body" do
      body.replace(<<-BODY)
        Fixes https://foobar.atlassian.net/browse/XY-123 and
        https://foobar.atlassian.net/browse/AB-666
      BODY

      pr.jira_issues.must_equal [
        Changeset::JiraIssue.new("https://foobar.atlassian.net/browse/XY-123"),
        Changeset::JiraIssue.new("https://foobar.atlassian.net/browse/AB-666")
      ]
    end

    it "returns an empty array if there are no JIRA references" do
      pr.jira_issues.must_equal []
    end
  end
end
