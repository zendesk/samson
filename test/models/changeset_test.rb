require_relative '../test_helper'

describe Changeset do
  describe "#comparison" do
    it "builds a new changeset" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal :x => "y"
    end

    it "caches" do
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal :x => "y"
      stub_github_api("repos/foo/bar/compare/a...b", "x" => "z")
      Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal :x => "y"
    end

    {
      Octokit::NotFound => "Github: Not found",
      Octokit::Unauthorized => "Github: Unauthorized",
      Octokit::InternalServerError => "Github: Internal server error",
    }.each do |exception, message|
      it "catches #{exception} exceptions" do
        GITHUB.expects(:compare).raises(exception)
        comparison = Changeset.new("foo/bar", "a", "b").comparison
        comparison.error.must_equal message
      end
    end
  end

  describe "#last_commit_status" do
    let(:comparison) { OpenStruct.new }

    before do
      c1 = { "sha" => "a", "message" => "Merge pull request #42"}
      c2 = { "sha" => "b", "message" => "Fix typo"}
      comparison.stubs(:commits).returns([c1, c2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)
      GITHUB.stubs(:combined_status).with("foo/bar", "b").returns({:state => "success"})
    end

    it "returns the status of the last commit message according to github" do
      last_status = Changeset.new("foo/bar", "a", "b").last_commit_status.state
      last_status.must_equal "success"
    end

    it "caches" do
      change_set = Changeset.new("foo/bar", "a", "b")
      change_set.last_commit_status
      GITHUB.stubs(:combined_status).with("foo/bar", "b").returns({:state => "failure"})
      last_status = change_set.last_commit_status
      last_status.state.must_equal "success"
    end

    {
      Octokit::NotFound => "Unable to retrieve commit status. Github: Not found",
      Octokit::Unauthorized => "Unable to retrieve commit status. Github: Unauthorized",
      Octokit::InternalServerError => "Unable to retrieve commit status. Github: Internal server error",
    }.each do |exception, message|
      it "catches #{exception} exceptions" do
        GITHUB.expects(:combined_status).raises(exception)
        last_commit_status = Changeset.new("foo/bar", "a", "b").last_commit_status
        last_commit_status.error.must_equal message
      end
    end
  end

  describe "#github_url" do
    it "returns a URL to a GitHub comparison page" do
      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.github_url.must_equal "https://github.com/foo/bar/compare/a...b"
    end
  end

  describe "#pull_requests" do
    let(:comparison) { stub("comparison") }

    it "finds pull requests mentioned in merge commits" do
      c1 = stub("commit1", commit: stub(message: "Merge pull request #42"))
      c2 = stub("commit2", commit: stub(message: "Fix typo"))
      comparison.stubs(:commits).returns([c1, c2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns("yeah!")
      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.pull_requests.must_equal ["yeah!"]
    end

    it "ignores invalid pull request numbers" do
      commit = stub("commit", commit: stub(message: "Merge pull request #42"))
      comparison.stubs(:commits).returns([commit])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)
      changeset = Changeset.new("foo/bar", "a", "b")

      changeset.pull_requests.must_equal []
    end
  end
end
