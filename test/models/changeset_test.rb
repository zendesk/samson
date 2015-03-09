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

    it "catches exceptions" do
      GITHUB.expects(:compare).raises(Octokit::NotFound)
      comparison = Changeset.new("foo/bar", "a", "b").comparison
      comparison.error.must_equal "Commit not found"
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

  describe "#zendesk_tickets" do
    let(:comparison) { stub("comparison") }

    it "returns a list of Zendesk tickets mentioned in commit messages" do
      c1 = stub("commit1", commit: stub(message: "ZD#1234 this fixes a very bad bug"))
      c2 = stub("commit2", commit: stub(message: "ZD4567 Fix typo"))
      comparison.stubs(:commits).returns([c1, c2])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.zendesk_tickets.must_equal [1234, 4567]
    end

    it "returns an empty array if there are no ticket references" do
      commit = stub("commit", commit: stub(message: "Fix build error"))
      comparison.stubs(:commits).returns([commit])
      GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

      changeset = Changeset.new("foo/bar", "a", "b")
      changeset.zendesk_tickets.must_equal [nil]
    end
  end
end
