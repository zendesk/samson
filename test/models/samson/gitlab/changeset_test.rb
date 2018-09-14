# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered! uncovered: 1

describe Samson::Gitlab::Changeset do
  let(:changeset) { Samson::Gitlab::Changeset.new("foo/bar", "a", "b") }

  describe "#comparison" do
    it "builds a new changeset" do
      payloads = {compare: {x: 'y'}, compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
      changeset.comparison.to_h.must_equal x: "y"
    end

    it "creates no comparison when the changeset is empty" do
      changeset = Samson::Gitlab::Changeset.new("foo/bar", "a", "a")
      changeset.comparison.class.must_equal Samson::Gitlab::Changeset::NullComparison
    end

    describe "with a specificed SHA" do
      it "caches" do
        payloads = {compare: {x: 'y'}, compare_args: [1, 'a', 'b'], commit_id: 'b'}
        ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
        Samson::Gitlab::Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal x: "y"
        Samson::Gitlab::Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal x: "y"
      end
    end

    describe "with master" do
      it "doesn't cache" do
        payloads = {compare: {x: 'y'}, compare_args: [1, 'a', 'foo'], commit_id: 'foo'}
        ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
        Samson::Gitlab::Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "y"

        payloads = {compare: {x: 'z'}, compare_args: [1, 'a', 'bar'], commit_id: 'bar'}
        ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
        Samson::Gitlab::Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "z"
      end
    end

    describe 'handles gitlab errors' do
      {
        Gitlab::Error::MissingCredentials => 'Gitlab::Error::MissingCredentials',
        Gitlab::Error::Parsing => 'Gitlab::Error::Parsing',
        Gitlab::Error::BadRequest => 'Gitlab::Error::BadRequest',
        Gitlab::Error::Unauthorized => 'Gitlab::Error::Unauthorized',
        Gitlab::Error::Forbidden => 'Gitlab::Error::Forbidden',
        Gitlab::Error::NotFound => 'Gitlab::Error::NotFound',
        Gitlab::Error::MethodNotAllowed => 'Gitlab::Error::MethodNotAllowed',
        Gitlab::Error::Conflict => 'Gitlab::Error::Conflict',
        Gitlab::Error::Unprocessable => 'Gitlab::Error::Unprocessable',
        Gitlab::Error::InternalServerError => 'Gitlab::Error::InternalServerError',
        Gitlab::Error::BadGateway => 'Gitlab::Error::BadGateway',
        Gitlab::Error::ServiceUnavailable => 'Gitlab::Error::ServiceUnavailable',
      }.each do |exception, message|
        it "catches #{exception} exceptions" do
          ::Gitlab::Client.stubs(:new).returns(mock_error_client(exception))
          comparison = Samson::Gitlab::Changeset.new("foo/bar", "a", "b").comparison
          comparison.error.must_equal message
        end
      end
    end

    # tests config/initializers/octokit.rb Octokit::RedirectAsError
    it "converts a redirect into a NullComparison" do
      payloads = {compare: OpenStruct.new(files: ['foo', 'bar'], commit: OpenStruct.new(id: 1)), compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
      Samson::Gitlab::Changeset.new("foo/bar", "a", "master").comparison.class.must_equal Samson::Gitlab::Changeset::NullComparison
    end
  end

  describe "#github_url" do
    it "returns a URL to a GitHub comparison page" do
      changeset.url.must_equal "https://gitlab.com/foo/bar/compare/a...b"
    end
  end

  describe "#files" do
    it "returns compared files" do
      diff_hash1 = {'old_path' => 'foo', 'new_path' => 'new_path', 'diff' => 'patch', 'renamed_file' => false, 'new_file' => false, 'deleted_file' => false }
      diff_hash2 = {'old_path' => 'bar', 'new_path' => 'new_path', 'diff' => 'patch', 'renamed_file' => false, 'new_file' => false, 'deleted_file' => false }
      payloads = {compare: OpenStruct.new(files: ['foo', 'bar'], diffs: [diff_hash1, diff_hash2], commit: OpenStruct.new(id: 1)), compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
      changeset.files.count.must_equal 2
      assert(changeset.files.detect{|file| file.previous_filename == 'foo'}, 'File not found')
      assert(changeset.files.detect{|file| file.previous_filename == 'bar'}, 'File not found')
    end
  end

  describe "#pull_requests" do
    let(:commit1) { {'title' => 'Merge pull request #42'} }
    let(:commit2) { {'title' => 'Fix typo'} }

    it "finds pull requests mentioned in merge commits" do
      payloads = {compare: OpenStruct.new(commits: []), compare_args: [1, 'a', 'b'], merge_requests: ['yeah!']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))

      Samson::Gitlab::Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns("yeah!")

      changeset.pull_requests.must_equal ["yeah!"]
    end

    it "finds pull requests open for a branch" do
      payloads = {compare: OpenStruct.new(commits: [commit2]), compare_args: [1, 'a', 'b'], merge_requests: ['yeah!']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))

      changeset.pull_requests.must_equal ["yeah!"]
    end

    it "does not fail if fetching pull request from Gitlab fails" do
      payloads = {compare: OpenStruct.new(commits: [commit2]), compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))

      changeset.pull_requests.must_equal []
    end

    it "skips fetching pull request for non PR branches" do
      payloads = {compare: OpenStruct.new(commits: [commit2]), compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
      %w[abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd master v123].each do |reference|
        changeset = Samson::Gitlab::Changeset.new("foo/bar", "a", reference)
        changeset.pull_requests.must_equal []
      end
    end

    it "ignores invalid pull request numbers" do
      payloads = {compare: OpenStruct.new(commits: [commit1]), compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))

      Samson::Gitlab::Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)

      changeset.pull_requests.must_equal []
    end

    it 'handles errors in pull requests' do
      ::Gitlab::Client.stubs(:new).returns(mock_error_client(StandardError))
      changeset.pull_requests.must_equal []
    end
  end

  describe "#risks?" do
    it "is risky when there are risky requests" do
      changeset.expects(:pull_requests).returns([stub("commit", risky?: true)])
      changeset.risks?.must_equal true
    end

    it "is not risky when there are no risky requests" do
      changeset.expects(:pull_requests).returns([stub("commit", risky?: false)])
      changeset.risks?.must_equal false
    end
  end

  describe "#jira_issues" do
    it "returns a list of jira issues" do
      changeset.expects(:pull_requests).returns([stub("commit", jira_issues: [1, 2])])
      changeset.jira_issues.must_equal [1, 2]
    end
  end

  describe "#authors" do
    it "returns a list of authors" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "foo"),
          stub("c3", author_name: "bar")
        ]
      )
      changeset.authors.must_equal ["foo", "bar"]
    end

    it "does not include nil authors" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "bar"),
          stub("c3", author_name: nil)
        ]
      )
      changeset.authors.must_equal ["foo", "bar"]
    end
  end

  describe "#author_names" do
    it "returns a list of author's names" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "foo"),
          stub("c3", author_name: "bar")
        ]
      )
      changeset.author_names.must_equal ["foo", "bar"]
    end

    it "doesnot include nil author names" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "bar"),
          stub("c3", author_name: nil)
        ]
      )
      changeset.author_names.must_equal ["foo", "bar"]
    end
  end

  describe "#error" do
    it "returns error" do
      payloads = {compare: OpenStruct.new(error: 'foo'), compare_args: [1, 'a', 'b']}
      ::Gitlab::Client.stubs(:new).returns(mock_client(payloads))
      changeset.error.must_equal "foo"
    end
  end

  describe Samson::Gitlab::Changeset::NullComparison do
    it "has no commits" do
      Samson::Gitlab::Changeset::NullComparison.new(nil).commits.must_equal []
    end

    it "has no files" do
      Samson::Gitlab::Changeset::NullComparison.new(nil).files.must_equal []
    end
  end

  def mock_projects
    mps = Minitest::Mock.new
    mps.expect(:project, mock_project)
    def mps.auto_paginate
      yield project
    end
    mps
  end

  def mock_project
    mp = Minitest::Mock.new
    mp.expect(:path_with_namespace, 'foo/bar')
    mp.expect(:id, 1)
  end

  def mock_client(payloads)
    mc = Minitest::Mock.new
    mc.expect(:projects, mock_projects, [per_page: 20])
    mc.expect(:compare, payloads[:compare], payloads[:compare_args])
    mc.expect(:merge_requests, payloads[:merge_requests]  || [], ["foo/bar", head: "foo:b"] )
    mc.expect(:branch, OpenStruct.new(commit: OpenStruct.new({id: payloads[:commit_id]})), [1, 'master'])
    mc
  end

  def mock_error_client(exception_class)
    mc = Minitest::Mock.new
    mc.expect(:projects, mock_projects, [per_page: 20])
    mc.expect(:klass, exception_class)
    def mc.compare(x, y, z)
      error_class = klass
      raise error_class.name
    end

    def mc.merge_requests(x,y)
      raise 'merge request failed.'
    end
    mc
  end

  #def maxitest_timeout;false;end
end
