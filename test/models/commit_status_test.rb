# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CommitStatus do
  let(:user_repo_part) { 'test/test' }
  let(:reference) { 'master' }
  let(:url) { "repos/#{user_repo_part}/commits/#{reference}/status" }
  let(:status) { CommitStatus.new(user_repo_part, reference) }

  describe "#status" do
    it "returns state" do
      stub_github_api(url, state: "success")
      status.status.must_equal 'success'
    end

    it "returns failure when not found" do
      stub_github_api(url, nil, 404)
      status.status.must_equal 'failure'
    end
  end

  describe "#status_list" do
    it "returns list" do
      stub_github_api(url, statuses: [{foo: "bar"}])
      status.status_list.must_equal [{foo: "bar"}]
    end

    it "returns failure on Reference when not found list for consistent status display" do
      stub_github_api(url, nil, 404)
      status.status_list.map { |s| s[:state] }.must_equal ["Reference"]
    end
  end
end
