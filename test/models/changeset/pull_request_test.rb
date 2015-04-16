require_relative '../../test_helper'

describe Changeset::PullRequest do
  DataStruct = Struct.new(:user, :merged_by, :body, :title)
  UserStruct = Struct.new(:login)

  let(:data) { DataStruct.new(user, merged_by, body) }
  let(:pr) { Changeset::PullRequest.new("xxx", data) }
  let(:user) { UserStruct.new("foo") }
  let(:merged_by) { UserStruct.new("bar") }
  let(:body) { "" }

  describe ".find" do
    it "finds the pull request" do
      GITHUB.stubs(:pull_request).with("foo/bar", 42).returns(data)
      data.title = "Make it bigger!"

      pr = Changeset::PullRequest.find("foo/bar", 42)

      pr.title.must_equal "Make it bigger!"
    end

    it "returns nil if the pull request could not be found" do
      GITHUB.stubs(:pull_request).with("foo/bar", 42).raises(Octokit::NotFound)

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

    describe 'nil users' do
      let(:merged_by) { nil }

      it 'excludes nil users' do
        pr.users.map(&:login).must_equal ['foo']
      end
    end
  end

  describe "#title_without_jira" do
    before do
      GITHUB.stubs(:pull_request).with("foo/bar", 42).returns(data)
      pr = Changeset::PullRequest.find("foo/bar", 42)
    end

    it "scrubs the JIRA from the PR title (with square brackets)" do
      data.stubs(:title).returns("[VOICE-1233] Make it bigger!")
      pr.title_without_jira.must_equal "Make it bigger!"
    end

    it "scrubs the JIRA from the PR title (without square brackets)" do
      data.stubs(:title).returns("VOICE-123 Make it bigger!")
      pr.title_without_jira.must_equal "Make it bigger!"
    end
  end

  describe "#jira_issues" do
    let(:data_nil_body) { stub("data", user: user, body: nil) }
    let(:pr_no_body) { Changeset::PullRequest.new("xxx", data_nil_body) }

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

    it "returns an empty array if body is missing" do
      pr_no_body.jira_issues.must_equal []
    end
  end

  describe "#risks" do
    def add_risks
      body.replace(<<-BODY.strip_heredoc)
        # Risks
         - Explosions
      BODY
    end

    def no_risks
      body.replace(<<-BODY.strip_heredoc)
        Not that risky ...
      BODY
    end

    before { add_risks }

    it "finds risks" do
      pr.risks.must_equal "- Explosions"
    end

    it "caches risks" do
      pr.risks
      no_risks
      pr.risks.must_equal "- Explosions"
    end

    it "does not find - None" do
      body.replace(<<-BODY.strip_heredoc)
        # Risks
         - None
      BODY
      pr.risks.must_equal nil
    end

    it "does not find None" do
      body.replace(<<-BODY.strip_heredoc)
        # Risks
        None
      BODY
      pr.risks.must_equal nil
    end

    context "with nothing risky" do
      before { no_risks }

      it "finds nothing" do
        pr.risks.must_equal nil
      end

      it "caches nothing" do
        pr.risks
        add_risks
        pr.risks.must_equal nil
      end
    end
  end
end
