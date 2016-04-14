require_relative '../../test_helper'

SingleCov.covered! uncovered: 8

describe Changeset::Commit do
  let(:commit_data) { stub }
  let(:data) { stub("data", commit: commit_data) }
  let(:commit) { Changeset::Commit.new("foo/bar", data) }

  describe "#summary" do
    it "returns the first line of the commit message" do
      commit_data.stubs(:message).returns("Hello, World!\nHow are you doing?")
      commit.summary.must_equal "Hello, World!"
    end

    it "truncates the line to 80 characters" do
      commit_data.stubs(:message).returns("Hello! " * 20)
      commit.summary.length.must_equal 80
    end
  end

  describe "#pull_request_number" do
    it "returns the PR number of a Pull Request merge" do
      commit_data.stubs(:message).returns("Merge pull request #136 from foobar")
      commit.pull_request_number.must_equal 136
    end

    it "returns nil if the commit is not a Pull Request merge" do
      commit_data.stubs(:message).returns("Add another bug")
      commit.pull_request_number.must_be_nil
    end
  end

  describe "#hotfix?" do
    it "returns true if the commit message starts with HOTFIX" do
      commit_data.stubs(:message).returns("HOTFIX: DANCE!")
      assert commit.hotfix?
    end

    it "returns false if the commit message does not start with HOTFIX" do
      commit_data.stubs(:message).returns("JUST DANCE!")
      assert !commit.hotfix?
    end
  end
end
