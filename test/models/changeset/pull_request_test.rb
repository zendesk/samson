require 'test_helper'

describe Changeset::PullRequest do
  let(:data) { stub("data", user: user, merged_by: merged_by, body: body) }
  let(:pr) { Changeset::PullRequest.new("xxx", data) }
  let(:user) { stub(login: "foo") }
  let(:merged_by) { stub(login: "bar") }
  let(:body) { "" }

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
