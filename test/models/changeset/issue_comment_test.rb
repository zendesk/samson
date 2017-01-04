# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Changeset::IssueComment do
  let(:project) { projects(:test) }
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

  describe ".valid_webhook?" do
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
      assert Changeset::IssueComment.valid_webhook?(webhook_data)
    end

    it 'is not valid for deleted comments' do
      webhook_data[:github][:action] = 'deleted'
      refute Changeset::IssueComment.valid_webhook?(webhook_data)
    end

    it 'is not valid for edited comments' do
      webhook_data[:github][:action] = 'edited'
      refute Changeset::IssueComment.valid_webhook?(webhook_data)
    end
  end

  describe ".changeset_from_webhook" do
    it "builds a new instance" do
      Changeset::IssueComment.changeset_from_webhook(project, {}).class.must_equal Changeset::IssueComment
    end
  end

  describe '#sha' do
    it 'shows the latest PR sha' do
      GITHUB.stubs(:pull_request).with("foo/bar", 1).returns(pr_data)
      issue = Changeset::IssueComment.new('foo/bar', issue_data)
      issue.sha.must_equal 'abcd123'
    end
  end

  describe '#branch' do
    it 'shows the PR branch' do
      GITHUB.stubs(:pull_request).with("foo/bar", 1).returns(pr_data)
      issue = Changeset::IssueComment.new('foo/bar', issue_data)
      issue.branch.must_equal 'a/test'
    end
  end

  describe "#service_type" do
    it "is pull_request" do
      Changeset::IssueComment.new('foo/bar', {}).service_type.must_equal 'pull_request'
    end
  end
end
