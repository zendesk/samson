# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Gitlab::CommitPresenter do
  let(:commit) do
    {
      id: 'bar',
      author_name: 'Author Test',
      author_email: 'test@test.com',
      message: 'Initial commit'
    }.stringify_keys
  end
  let(:gitlab_commit) { Gitlab::CommitPresenter.new(commit) }

  describe "#build" do
    it "builds a new commit" do
      commit = gitlab_commit.build
      commit.sha.must_equal 'bar'
      commit.commit.author.name.must_equal 'Author Test'
      commit.commit.author.email.must_equal 'test@test.com'
      commit.commit.message.must_equal 'Initial commit'
    end
  end
end
