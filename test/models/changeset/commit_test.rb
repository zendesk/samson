require 'test_helper'

describe Changeset::Commit do
  describe "#summary" do
    let(:commit_data) { stub }
    let(:data) { stub("data", commit: commit_data) }
    let(:commit) { Changeset::Commit.new("foo/bar", data) }

    it "returns the first line of the commit message" do
      commit_data.stubs(:message).returns("Hello, World!\nHow are you doing?")
      commit.summary.must_equal "Hello, World!"
    end

    it "truncates the line to 80 characters" do
      commit_data.stubs(:message).returns("Hello! " * 20)
      commit.summary.length.must_equal 80
    end
  end
end
