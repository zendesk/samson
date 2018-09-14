# frozen_string_literal: true
require_relative '../../../../test_helper'

SingleCov.covered!

describe Samson::Gitlab::Changeset::File do
  before :each do
    patch = "--- a/files/js/application.js\n+++ b/files/js/application.js\n@@ -24,8 +24,10 @@\n //= require g.raphael-min\n //= require g.bar-min\n //= require branch-graph\n-//= require highlightjs.min\n-//= require ace/ace\n //= require_tree .\n //= require d3\n //= require underscore\n+\n+function fix() { \n+  alert(\"Fixed\")\n+}"
    @diff_hash = {'old_path' => 'old_path', 'new_path' => 'new_path', 'diff' => patch, 'renamed_file' => false, 'new_file' => false, 'deleted_file' => false }
    @file = Samson::Gitlab::Changeset::File.new("foo/bar", 'abc123', @diff_hash)
  end

  describe 'commit differences' do
    it 'returns current file name' do
      assert_equal(@diff_hash['new_path'], @file.filename)
    end

    it 'returns old file name' do
      assert_equal(@diff_hash['old_path'], @file.previous_filename)
    end

    it 'returns patch' do
      assert_equal(@diff_hash['diff'], @file.patch)
    end

    it 'returns renamed status' do
      @diff_hash['renamed_file'] = true
      file = Samson::Gitlab::Changeset::File.new("foo/bar", 'abc123', @diff_hash)
      assert_equal('renamed', file.status)
    end

    it 'returns added status' do
      @diff_hash['new_file'] = true
      file = Samson::Gitlab::Changeset::File.new("foo/bar", 'abc123', @diff_hash)
      assert_equal('added', file.status)
    end

    it 'returns removed status' do
      @diff_hash['deleted_file'] = true
      file = Samson::Gitlab::Changeset::File.new("foo/bar", 'abc123', @diff_hash)
      assert_equal('removed', file.status)
    end

    it 'returns changed status' do
      assert_equal('changed', @file.status)
    end
  end

  describe 'commit stats' do
    before :each do
      commit_mock = Minitest::Mock.new
      commit_mock.expect(:commit, OpenStruct.new(stats: {'additions' => 5, 'deletions' => 2}), ['foo/bar', 'abc123'])
      Gitlab::Client.stubs(:new).returns(commit_mock)
    end

    it 'properly counts additions' do
      assert_equal(5, @file.additions)
    end

    it 'properly counts deletions' do
      assert_equal(2, @file.deletions)
    end
  end

  describe 'missing commit' do
     before :each do
       commit_mock = Minitest::Mock.new
       commit_mock.expect(:commit, nil, ['foo/bar', 'abc123'])
       Gitlab::Client.stubs(:new).returns(commit_mock)
     end

     it 'additions and deletions are zero' do
       assert_equal(0, @file.additions)
       assert_equal(0, @file.deletions)
     end
  end

  def maxitest_timeout;false;end
end
