# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Changeset do
  let(:project) { Project.new(repository_url: 'ssh://git@github.com:foo/bar.git') }
  let(:changeset) { Changeset.new(project, "a", "b") }

  before { stub_github_api("repos/foo/bar/commits/b", sha: "123") }

  describe "#comparison" do
    it "builds a new changeset" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      changeset.comparison.to_h.must_equal x: "y"
    end

    it "creates no comparison when the changeset is empty" do
      changeset = Changeset.new(project, "a", "a")
      changeset.comparison.class.must_equal Changeset::NullComparison
    end

    it "caches SHA compares" do
      request = stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      2.times { Changeset.new(project, "a", "b").comparison.to_h.must_equal x: "y" }
      assert_requested request
    end

    it "caches tag compares" do
      request = stub_github_api("repos/foo/bar/compare/a...v1", "x" => "y")
      2.times { Changeset.new(project, "a", "v1").comparison.to_h.must_equal x: "y" }
      assert_requested request
    end

    it "does not cache branch compares" do
      stub_github_api("repos/foo/bar/commits/master", sha: "foo")
      stub_github_api("repos/foo/bar/compare/a...master", "x" => "y")
      Changeset.new(project, "a", "master").comparison.to_h.must_equal x: "y"

      stub_github_api("repos/foo/bar/commits/master", sha: "bar")
      stub_github_api("repos/foo/bar/compare/a...master", "x" => "z")
      Changeset.new(project, "a", "master").comparison.to_h.must_equal x: "z"
    end

    {
      Octokit::NotFound => "Repository error: NotFound",
      Octokit::Unauthorized => "Repository error: Unauthorized",
      Octokit::InternalServerError => "Repository error: InternalServerError",
      Octokit::RepositoryUnavailable => "Repository error: RepositoryUnavailable", # used to signal redirects too
      Faraday::ConnectionFailed.new("Oh no") => "Repository error: Oh no"
    }.each do |exception, message|
      it "catches #{exception} exceptions" do
        GITHUB.expects(:compare).raises(exception)
        comparison = Changeset.new(project, "a", "b").comparison
        comparison.error.must_equal message
      end
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "converts a redirect into a NullComparison" do
      stub_github_api("repos/foo/bar/commits/master", {}, 301)
      stub_github_api("repos/foo/bar/compare/a...master", {}, 301)
      Changeset.new(project, "a", "master").comparison.class.must_equal Changeset::NullComparison
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "uses the cached body of a 304" do
      stub_github_api("repos/foo/bar/commits/master", {sha: "bar"}, 304)
      stub_github_api("repos/foo/bar/compare/a...master", "x" => "z")
      Changeset.new(project, "a", "master").comparison.to_h.must_equal x: "z"
    end

    it "creates a null compare for local projects" do
      project.stubs(:github?)
      project.stubs(:gitlab?)
      comparison = Changeset.new(project, "a", "b").comparison
      comparison.class.must_equal Changeset::NullComparison
    end
  end

  describe "#commit_range_url" do
    it "returns a URL to a GitHub comparison page" do
      changeset.commit_range_url.must_equal "https://github.com/foo/bar/compare/a...b"
    end
  end

  describe "#files" do
    it "returns compared files" do
      stub_github_api("repos/foo/bar/compare/a...b", files: ["foo", "bar"])
      changeset.files.must_equal ["foo", "bar"]
    end
  end

  describe "#pull_requests" do
    def stub_compare(a, b, commits)
      stub_github_api("repos/foo/bar/commits/#{b}", sha: "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd")
      comparison = Sawyer::Resource.new(sawyer_agent, commits: commits)
      GITHUB.stubs(:compare).with("foo/bar", a, b).returns(comparison)
    end

    let(:sawyer_agent) { Sawyer::Agent.new('') }
    let(:commit_merge) do
      Sawyer::Resource.new(sawyer_agent, commit: Sawyer::Resource.new(sawyer_agent, message: 'Merge pull request #42'))
    end
    let(:commit_simple) do
      Sawyer::Resource.new(sawyer_agent, commit: Sawyer::Resource.new(sawyer_agent, message: 'Fix typo'))
    end
    let(:pr_from_coolcommitter) do
      Sawyer::Resource.new(
        sawyer_agent,
        user: {login: 'coolcommitter'},
        additions: 10
      )
    end
    let(:prs_from_coolcommitter) do
      [
        Sawyer::Resource.new(
          sawyer_agent,
          user: {
            login: 'coolcommitter'
          },
          number: 5
        )
      ]
    end
    let(:pr_from_coolcommitter_wrapped) { Changeset::PullRequest.new("foo/bar", pr_from_coolcommitter) }

    it "finds merged pull requests mentioned in merge commits" do
      stub_compare "a", "b", [commit_merge, commit_simple]
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").returns([])

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(pr_from_coolcommitter_wrapped)

      changeset.pull_requests.size.must_equal 1
      changeset.pull_requests.first.users.first.login.must_equal 'coolcommitter'
    end

    it "finds open pull requests for a branch" do
      stub_compare "a", "b", [commit_simple]
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").returns(prs_from_coolcommitter)
      GITHUB.stubs(:pull_request).with("foo/bar", 5).returns(pr_from_coolcommitter)

      pull_requests = changeset.pull_requests

      pull_requests.size.must_equal 1
      pull_requests.first.users.first.login.must_equal 'coolcommitter'
      pull_requests.first.additions.must_equal 10
    end

    it "does not fail if fetching open pull request from Github fails" do
      stub_compare "a", "b", [commit_simple]
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").raises(Octokit::Error)
      changeset.pull_requests.must_equal []
    end

    it "does not load open pull requests for tags because they never exist" do
      stub_compare "a", "v1", [commit_simple]
      Changeset.new(project, "a", "v1").pull_requests
    end

    it "does not load open pull requests for shas because they are not supported" do
      sha = "b" * 40
      stub_compare "a", sha, [commit_simple]
      Changeset.new(project, "a", sha).pull_requests
    end

    it "does not load open pull requests for head branches because nobody uses them to pull from" do
      stub_compare "a", "master", [commit_simple]
      Changeset.new(project, "a", "master").pull_requests
    end

    it "ignores invalid pull request numbers" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit_merge])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").returns([])

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)

      changeset.pull_requests.must_equal []
    end
  end

  describe "#risks?" do
    it "is risky when there are risky requests" do
      changeset.expects(:pull_requests).returns([stub("commit", risky?: true)])
      changeset.risks?.must_equal true
    end

    it "is not risky when there are no risky requests" do
      changeset.expects(:pull_requests).returns([stub("commit", risky?: false)])
      changeset.risks?.must_equal false
    end
  end

  describe "#jira_issues" do
    it "returns a list of jira issues" do
      changeset.expects(:pull_requests).returns([stub("commit", jira_issues: [1, 2])])
      changeset.jira_issues.must_equal [1, 2]
    end
  end

  describe "#authors" do
    it "returns a list of authors" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author: "foo"),
          stub("c2", author: "foo"),
          stub("c3", author: "bar")
        ]
      )
      changeset.authors.must_equal ["foo", "bar"]
    end

    it "does not include nil authors" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author: "foo"),
          stub("c2", author: "bar"),
          stub("c3", author: nil)
        ]
      )
      changeset.authors.must_equal ["foo", "bar"]
    end
  end

  describe "#author_names" do
    it "returns a list of author's names" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "foo"),
          stub("c3", author_name: "bar")
        ]
      )
      changeset.author_names.must_equal ["foo", "bar"]
    end

    it "doesnot include nil author names" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "bar"),
          stub("c3", author_name: nil)
        ]
      )
      changeset.author_names.must_equal ["foo", "bar"]
    end
  end

  describe "#error" do
    it "returns error" do
      stub_github_api("repos/foo/bar/compare/a...b", error: "foo")
      changeset.error.must_equal "foo"
    end
  end

  describe Changeset::NullComparison do
    it "has no commits" do
      Changeset::NullComparison.new.commits.must_equal []
    end

    it "has no files" do
      Changeset::NullComparison.new.files.must_equal []
    end

    it "has no error" do
      Changeset::NullComparison.new.error.must_be_nil
    end

    it "can have error" do
      Changeset::NullComparison.new(error: "a").error.must_equal "a"
    end
  end
end
