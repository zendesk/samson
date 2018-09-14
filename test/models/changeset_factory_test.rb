# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 5

describe ChangesetFactory do
  describe 'Github factory tests' do
    before :each do
      Rails.application.config.samson.stubs(:remote_repository).returns('github')
    end

    it 'returns github changeset' do
      assert_equal(ChangesetFactory.changeset, Samson::Github::Changeset)
    end

    it 'returns github pull request' do
      assert_equal(ChangesetFactory.pull_request, Samson::Github::Changeset::PullRequest)
    end

    it 'returns github attribute tabs' do
      assert_equal(ChangesetFactory.attribute_tabs, Samson::Github::Changeset::ATTRIBUTE_TABS)
    end

    it 'returns github code push' do
      assert_equal(ChangesetFactory.code_push, Samson::Github::Changeset::CodePush)
    end

    it 'returns github issue comment' do
      assert_equal(ChangesetFactory.issue_comment, Samson::Github::Changeset::IssueComment)
    end

    it 'returns github commit' do
      assert_equal(ChangesetFactory.commit, Samson::Github::Changeset::Commit)
    end
  end

  describe 'Gitlab factory tests' do
    before :each do
      Rails.application.config.samson.stubs(:remote_repository).returns('gitlab')
    end

    it 'returns gitlab changeset' do
      assert_equal(ChangesetFactory.changeset, Samson::Gitlab::Changeset)
    end

    it 'returns gitlab pull request' do
      assert_equal(ChangesetFactory.pull_request, Samson::Gitlab::Changeset::PullRequest)
    end

    it 'returns gitlab attribute tabs' do
      assert_equal(ChangesetFactory.attribute_tabs, Samson::Gitlab::Changeset::ATTRIBUTE_TABS)
    end

    it 'returns gitlab code push' do
      assert_equal(ChangesetFactory.code_push, Samson::Gitlab::Changeset::CodePush)
    end

    it 'returns gitlab issue comment' do
      assert_equal(ChangesetFactory.issue_comment, Samson::Gitlab::Changeset::IssueComment)
    end

    it 'returns gitlab commit' do
      assert_equal(ChangesetFactory.commit, Samson::Gitlab::Changeset::Commit)
    end
  end
end
