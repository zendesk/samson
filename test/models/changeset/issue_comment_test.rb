# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 8

describe Changeset::IssueComment do
  describe ".valid_webhook" do
    let(:webhook_data) do
      {
        github: {},
        comment: {
          body: '[samson review]'
        },
      }.with_indifferent_access
    end

    it 'is valid for new comments' do
      webhook_data[:github][:action] = 'created'
      Changeset::IssueComment.valid_webhook?(webhook_data).must_equal true
    end

    it 'is not valid for deleted comments' do
      webhook_data[:github][:action] = 'deleted'
      Changeset::IssueComment.valid_webhook?(webhook_data).must_equal false
    end

    it 'is not valid for edited comments' do
      webhook_data[:github][:action] = 'edited'
      Changeset::IssueComment.valid_webhook?(webhook_data).must_equal false
    end
  end

  describe '#sha' do
    let(:issue_data) do
      {
        issue: {
          number: 1
        },
        comment: {
          id: 123
        }
      }.with_indifferent_access
    end

    let(:pr_data) do
      {
        head: {
          sha: 'abcd123',
          ref: 'a/test'
        }
      }.with_indifferent_access
    end

    let(:cached_pr_data) do
      {
        head: {
          sha: 'cach123',
          ref: 'a/test'
        }
      }.with_indifferent_access
    end

    it 'shows the latest sha when a new comment is made' do
      Rails.cache.write(['Changeset::PullRequest', 'foo/bar', 1].join("-"), cached_pr_data)
      Rails.cache.write(['IssueComment', 'foo/bar', 1].join("-"), cached_pr_data)
      GITHUB.stubs(:pull_request).with("foo/bar", 1).returns(pr_data)
      issue = Changeset::IssueComment.new('foo/bar', issue_data)
      issue.sha.must_equal 'abcd123'
    end
  end
end
