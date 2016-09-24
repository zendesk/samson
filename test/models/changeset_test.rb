# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 12

describe Changeset do
  describe "#comparison" do
    it "builds a new changeset" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal x: "y"
    end

    describe "with a specificed SHA" do
      it "caches" do
        stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
        Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal x: "y"
        stub_github_api("repos/foo/bar/compare/a...b", "x" => "z")
        Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal x: "y"
      end
    end

    describe "with master" do
      it "doesn't cache" do
        stub_github_api("repos/foo/bar/branches/master", commit: { sha: "foo"})
        stub_github_api("repos/foo/bar/compare/a...foo", "x" => "y")
        Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "y"

        stub_github_api("repos/foo/bar/branches/master", commit: { sha: "bar"})
        stub_github_api("repos/foo/bar/compare/a...bar", "x" => "z")
        Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "z"
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
        comparison = Changeset.new("foo/bar", "a", "b").comparison
        comparison.error.must_equal message
      end
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "converts a redirect into a NullComparison" do
      stub_github_api("repos/foo/bar/branches/master", {}, 301)
      Changeset.new("foo/bar", "a", "master").comparison.class.must_equal Changeset::NullComparison
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "uses the cached body of a 304" do
      stub_github_api("repos/foo/bar/branches/master", {commit: { sha: "bar"}}, 304)
      stub_github_api("repos/foo/bar/compare/a...bar", "x" => "z")
      Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "z"
    end
  end

  describe "#github_url" do
    it "returns a URL to a GitHub comparison page" do
      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.github_url.must_equal "https://github.com/foo/bar/compare/a...b"
    end
  end

  describe "#pull_requests" do
    let(:sawyer_agent) { Sawyer::Agent.new('') }
    let(:commit1) { Sawyer::Resource.new(sawyer_agent, commit: message1) }
    let(:commit2) { Sawyer::Resource.new(sawyer_agent, commit: message2) }
    let(:message1) { Sawyer::Resource.new(sawyer_agent, message: 'Merge pull request #42') }
    let(:message2) { Sawyer::Resource.new(sawyer_agent, message: 'Fix typo') }

    it "finds pull requests mentioned in merge commits" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit1, commit2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns("yeah!")
      changeset = Changeset.new("foo/bar", "a", "b")

      changeset.pull_requests.must_equal ["yeah!"]
    end

    it "ignores invalid pull request numbers" do
      comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit1])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)
      changeset = Changeset.new("foo/bar", "a", "b")

      changeset.pull_requests.must_equal []
    end
  end
end
