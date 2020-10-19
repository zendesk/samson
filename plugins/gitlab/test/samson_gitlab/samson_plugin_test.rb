# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGitlab do
  let(:project) { Project.new(repository_url: 'ssh://git@gitlab.com:foo/bar.git') }
  let(:api_path) { "https://gitlab.com/api/v4/projects/foo%2Fbar/repository/" }

  it 'configures GitLab API client' do
    Gitlab.endpoint.must_equal "#{Rails.application.config.samson.gitlab.web_url}/api/v4"
    Gitlab.private_token.must_equal ENV['GITLAB_TOKEN']
  end

  describe :repo_commit_from_ref do
    def fire(commit)
      Samson::Hooks.fire(:repo_commit_from_ref, project, commit)
    end

    only_callbacks_for_plugin :repo_commit_from_ref

    it "skips non-gitlab" do
      project.stubs(:gitlab?).returns(false)
      fire("master").must_equal [nil]
    end

    it "resolves a reference" do
      stub_request(:get, "#{api_path}branches/master").to_return(body: JSON.dump(commit: {id: 'foo'}))
      fire("master").must_equal ["foo"]
    end
  end

  describe :repo_compare do
    def fire(a, b)
      Samson::Hooks.fire(:repo_compare, project, a, b)
    end

    only_callbacks_for_plugin :repo_compare

    it "skips non-gitlab" do
      project.stubs(:gitlab?).returns(false)
      fire("a", "b").must_equal [nil]
    end

    it "builds a fake comparisson" do
      stub_request(:get, "#{api_path}compare?from=a&to=b").to_return(body: JSON.dump(diffs: [], commits: []))
      result = fire("a", "b")
      assert result.first.respond_to?(:commits)
      result.map(&:to_h).must_equal [{files: [], commits: []}]
    end
  end
end
