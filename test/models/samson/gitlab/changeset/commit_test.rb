# frozen_string_literal: true
require_relative '../../../../test_helper'

SingleCov.covered!

describe Samson::Gitlab::Changeset::Commit do
  let(:data) { {} }
  let(:commit) { Samson::Gitlab::Changeset::Commit.new("foo/bar", data) }

  describe "#author_name" do
    it "returns username that made the commit" do
      data['author_name'] = 'foo'
      commit.author_name.must_equal "foo"
    end
  end

  describe "#author_email" do
    it "returns the email address from the author" do
      data['author_email'] = "bar"
      commit.author_email.must_equal "bar"
    end
  end

  describe "#author" do
    it "returns a github user if there is an author" do
      data['author_email'] = 'author@plansource.com'
      commit.author.class.must_equal Samson::Gitlab::Changeset::GitlabUser
    end

    it "does not return any github user if there isn't an author" do
      data.stubs(author: nil)
      commit.author.must_equal nil
    end
  end

  describe "#summary" do
    it "returns the first line of the commit message" do
      data['title'] = "Hello, World!\nHow are you doing?"
      commit.summary.must_equal "Hello, World!"
    end

    it "truncates the line to 80 characters" do
      data['title'] = "Hello! " * 20
      commit.summary.length.must_equal 80
    end
  end

  describe "#sha" do
    it "returns a sha" do
      data['id'] = "aa2a33444343"
      commit.sha.must_equal "aa2a33444343"
    end
  end

  describe "#short_sha" do
    it "return a short sha" do
      data['id'] ="aa2a33444343"
      commit.short_sha.must_equal "aa2a334"
    end
  end

  describe "#pull_request_number" do
    it "returns the PR number of a Pull Request merge" do
      data['title'] = "Merge pull request #136 from foobar"
      commit.pull_request_number.must_equal 136
    end

    it "returns the PR number of a squasch merge" do
      data['title'] = "Something very good (#136)"
      commit.pull_request_number.must_equal 136
    end

    it "returns the PR number of a long squasch merge" do
      data['title'] = "Something very good (#136)\nfoobar"
      commit.pull_request_number.must_equal 136
    end

    it "does not fetch random other numbers" do
      data['title'] = "Something very bad (#136) here"
      commit.pull_request_number.must_equal nil
    end

    it "returns nil if the commit is not a Pull Request merge" do
      data['title'] = "Add another bug"
      commit.pull_request_number.must_be_nil
    end
  end

  describe "#url" do
    it "builds an url" do
      data['id'] = "aa2a33444343"
      commit.url.must_equal "https://gitlab.com/foo/bar/commit/aa2a33444343"
    end
  end

  describe 'status' do
    it 'returns a valid status' do
      mock_commit_status = Minitest::Mock.new
      author = OpenStruct.new(avatar_url: 'avatar_url', id: 1, state: 'author_state')
      mock_commit_status.expect(:commit_status, [OpenStruct.new(id: 1, success: true, description: 'status description',target_url: 'www.plansource.com', created_at: '', updated_at: '', author: author)], ['foo', 1, {ref: 'abc123'}])
      mock_commit_status.expect(:commit, OpenStruct.new(id: 1), ['foo', 'abc123'])

      ::Gitlab::Client.stubs(:new).returns(mock_commit_status)
      Samson::Gitlab::Changeset::Commit.status('foo', 'abc123')[:state].must_equal 'success'
    end

    it 'handles commit not found' do
      mock_commit_status = Minitest::Mock.new
      def mock_commit_status.commit_status(ref, sha)
        raise StandardError.new('fubar')
      end
      error_response = {state: "failure", statuses: [{"state": "Reference", description: "'abc123' does not exist for foo"}]}

      ::Gitlab::Client.stubs(:new).returns(mock_commit_status)
      Samson::Gitlab::Changeset::Commit.status('foo', 'abc123').must_equal error_response
    end
  end

  def maxitest_timeout;false;end
end
