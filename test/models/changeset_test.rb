# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Changeset do
  let(:project) { Project.new(repository_url: 'ssh://git@github.com:foo/bar.git') }
  let(:changeset) { Changeset.new(project, "a", "b") }

  describe "#comparison" do
    it "builds a new changeset" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      changeset.comparison.to_h.must_equal x: "y"
    end

    it "creates no comparison when the changeset is empty" do
      changeset = Changeset.new(project, "a", "a")
      changeset.comparison.class.must_equal Changeset::NullComparison
    end

    describe "with a specificed SHA" do
      it "caches" do
        request = stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
        2.times { Changeset.new(project, "a", "b").comparison.to_h.must_equal x: "y" }
        assert_requested request
      end
    end

    describe "with master" do
      describe "when GitHub project" do
        it "doesn't cache" do
          stub_github_api("repos/foo/bar/branches/master", commit: {sha: "foo"})
          stub_github_api("repos/foo/bar/compare/a...foo", "x" => "y")
          Changeset.new(project, "a", "master").comparison.to_h.must_equal x: "y"

          stub_github_api("repos/foo/bar/branches/master", commit: {sha: "bar"})
          stub_github_api("repos/foo/bar/compare/a...bar", "x" => "z")
          Changeset.new(project, "a", "master").comparison.to_h.must_equal x: "z"
        end
      end

      describe "when GitLab project" do
        it "doesn't cache" do
          project.repository_url = 'ssh://git@gitlab.com:foo/bar.git'
          stub_request(:get, "https://gitlab.com/api/v4/projects/foo%2Fbar/repository/branches/master").to_return(
            body: JSON.dump(commit: {id: 'foo'})
          )
          stub_request(:get, "https://gitlab.com/api/v4/projects/foo%2Fbar/repository/compare?from=a&to=foo").to_return(
            body: JSON.dump(diffs: [], commits: [])
          )
          Changeset.new(project, "a", "master").comparison.to_h.must_equal(files: [], commits: [])
        end
      end
    end

    {
      Octokit::NotFound => "GitHub: Not found",
      Octokit::Unauthorized => "GitHub: Unauthorized",
      Octokit::InternalServerError => "GitHub: Internal server error",
      Octokit::RepositoryUnavailable => "GitHub: Repository unavailable", # used to signal redirects too
      Faraday::ConnectionFailed.new("Oh no") => "GitHub: Oh no"
    }.each do |exception, message|
      it "catches #{exception} exceptions" do
        GITHUB.expects(:compare).raises(exception)
        comparison = Changeset.new(project, "a", "b").comparison
        comparison.error.must_equal message
      end
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "converts a redirect into a NullComparison" do
      stub_github_api("repos/foo/bar/branches/master", {}, 301)
      stub_github_api("repos/foo/bar/compare/a...master", {}, 301)
      Changeset.new(project, "a", "master").comparison.class.must_equal Changeset::NullComparison
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "uses the cached body of a 304" do
      stub_github_api("repos/foo/bar/branches/master", {commit: {sha: "bar"}}, 304)
      stub_github_api("repos/foo/bar/compare/a...bar", "x" => "z")
      Changeset.new(project, "a", "master").comparison.to_h.must_equal x: "z"
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
    let(:sawyer_agent) { Sawyer::Agent.new('') }
    let(:commit1) { Sawyer::Resource.new(sawyer_agent, commit: message1) }
    let(:commit2) { Sawyer::Resource.new(sawyer_agent, commit: message2) }
    let(:message1) { Sawyer::Resource.new(sawyer_agent, message: 'Merge pull request #42') }
    let(:message2) { Sawyer::Resource.new(sawyer_agent, message: 'Fix typo') }
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

    it "finds pull requests mentioned in merge commits" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit1, commit2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").returns([])

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(pr_from_coolcommitter_wrapped)

      changeset.pull_requests.size.must_equal 1
      changeset.pull_requests.first.users.first.login.must_equal 'coolcommitter'
    end

    it "finds pull requests open for a branch" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").returns(prs_from_coolcommitter)
      GITHUB.stubs(:pull_request).with("foo/bar", 5).returns(pr_from_coolcommitter)

      pull_requests = changeset.pull_requests

      pull_requests.size.must_equal 1
      pull_requests.first.users.first.login.must_equal 'coolcommitter'
      pull_requests.first.additions.must_equal 10
    end

    it "does not fail if fetching pull request from Github fails" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)
      GITHUB.stubs(:pull_requests).with("foo/bar", head: "foo:b").raises(Octokit::Error)

      changeset.pull_requests.must_equal []
    end

    it "skips fetching pull request for non PR branches" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit2])
      stub_github_api("repos/foo/bar/branches/master", commit: {sha: "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd"})
      GITHUB.stubs(:compare).returns(comparison)
      find_pr_stub = stub_github_api("repos/foo/bar/pulls", []).with(query: hash_including({}))

      %w[abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd master v123].each do |reference|
        changeset = Changeset.new(project, "a", reference)
        changeset.pull_requests
        assert_not_requested(find_pr_stub)
      end
    end

    it "ignores invalid pull request numbers" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit1])
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
      Changeset::NullComparison.new(nil).commits.must_equal []
    end

    it "has no files" do
      Changeset::NullComparison.new(nil).files.must_equal []
    end
  end
end
