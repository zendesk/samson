require 'test_helper'

describe Changeset do
  describe "#github_url" do
    it "returns a URL to a GitHub comparison page" do
      comparison = stub("comparison")
      changeset = Changeset.new(comparison, "foo/bar", "a", "b")
      changeset.github_url.must_equal "https://github.com/foo/bar/compare/a...b"
    end
  end
end
