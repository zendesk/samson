# frozen_string_literal: true
require_relative '../../test_helper'
require 'pry'
def maxitest_timeout;false;end

SingleCov.covered!

describe Changeset::Commit do
  let(:commit_data) { stub }
  let(:data) { stub("data", commit: commit_data, author: stub, sha: "aa2a33444343") }
  let(:commit) { Changeset::Commit.new("foo/bar", data) }

  let(:gitlab_commit_data) { stub }
  let(:gitlab_data) { stub("data", commit: gitlab_commit_data, sha: "444343aa2a33") }
  let(:gitlab_commit) { Changeset::Commit.new("foo/bar", gitlab_data, false) }

  describe "#author_name" do
    it "returns username that made the commit" do
      commit_data.stubs(author: stub(name: 'foo'))
      commit.author_name.must_equal "foo"

      gitlab_commit_data.stubs(author_name: 'bar')
      gitlab_commit.author_name.must_equal "bar"
    end
  end

  describe "#author_email" do
    it "returns the email address from the author" do
      commit_data.stubs(author: stub(email: "bar"))
      commit.author_email.must_equal "bar"

      gitlab_commit_data.stubs(author_email: "foo")
      gitlab_commit.author_email.must_equal "foo"
    end
  end

  describe "#author" do
    it "returns a github user if there is an author" do
      commit.author.class.must_equal Changeset::GithubUser
    end

    it "does not return any github user if there isn't an author" do
      data.stubs(author: nil)
      commit.author.must_equal nil
    end
  end

  describe "#summary" do
    it "returns the first line of the commit message" do
      commit_data.stubs(:message).returns("Hello, World!\nHow are you doing?")
      commit.summary.must_equal "Hello, World!"

      gitlab_commit_data.stubs(:title).returns("Hello, World!\nHow are you doing?")
      gitlab_commit.summary.must_equal "Hello, World!"
    end

    it "truncates the line to 80 characters" do
      commit_data.stubs(:message).returns("Hello! " * 20)
      commit.summary.length.must_equal 80

      gitlab_commit_data.stubs(:title).returns("Hello! " * 20)
      gitlab_commit.summary.length.must_equal 80
    end
  end

  describe "#sha" do
    it "returns a sha" do
      commit.sha.must_equal "aa2a33444343"

      gitlab_commit_data.stubs(:id).returns("444343aa2a33")
      gitlab_commit.sha.must_equal "444343aa2a33"
    end
  end

  describe "#short_sha" do
    it "return a short sha" do
      commit.short_sha.must_equal "aa2a334"

      gitlab_commit_data.stubs(:id).returns("444343a")
      gitlab_commit.short_sha.must_equal "444343a"
    end
  end

  describe "#pull_request_number" do
    it "returns the PR number of a Pull Request merge" do
      commit_data.stubs(:message).returns("Merge pull request #136 from foobar")
      commit.pull_request_number.must_equal 136
    end

    it "returns the PR number of a squasch merge" do
      commit_data.stubs(:message).returns("Something very good (#136)")
      commit.pull_request_number.must_equal 136
    end

    it "returns the PR number of a long squasch merge" do
      commit_data.stubs(:message).returns("Something very good (#136)\nfoobar")
      commit.pull_request_number.must_equal 136
    end

    it "does not fetch random other numbers" do
      commit_data.stubs(:message).returns("Something very bad (#136) here")
      commit.pull_request_number.must_equal nil
    end

    it "returns nil if the commit is not a Pull Request merge" do
      commit_data.stubs(:message).returns("Add another bug")
      commit.pull_request_number.must_be_nil
    end
  end

  describe "#url xxx" do
    it "builds an url" do
      commit.url.must_equal "https://github.com/foo/bar/commit/aa2a33444343"

      gitlab_commit_data.stubs(:id).returns("444343aa2a33")
      gitlab_commit.url.must_equal "https://gitlab.com/foo/bar/commit/444343aa2a33"
    end
  end

end
