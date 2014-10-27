require_relative '../test_helper'

describe Changeset do
  describe "#github_url" do
    it "returns a URL to a GitHub comparison page" do
      comparison = stub("comparison")
      changeset = Changeset.new(comparison, "foo/bar", "a", "b")
      changeset.github_url.must_equal "https://github.com/foo/bar/compare/a...b"
    end
  end

  describe "#pull_requests" do
    let(:comparison) { stub("comparison") }

    it "finds pull requests mentioned in merge commits" do
      c1 = stub("commit1", commit: stub(message: "Merge pull request #42"))
      c2 = stub("commit2", commit: stub(message: "Fix typo"))
      comparison.stubs(:commits).returns([c1, c2])

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns("yeah!")
      changeset = Changeset.new(comparison, "foo/bar", "a", "b")

      changeset.pull_requests.must_equal ["yeah!"]
    end

    it "ignores invalid pull request numbers" do
      commit = stub("commit", commit: stub(message: "Merge pull request #42"))
      comparison.stubs(:commits).returns([commit])

      Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)
      changeset = Changeset.new(comparison, "foo/bar", "a", "b")

      changeset.pull_requests.must_equal []
    end
  end
end
