# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::TddiumController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:commit_message) { "hi" }
  let(:project) { projects(:test) }
  let(:payload) do
    {
      "event" => "stop",
      "session" => 351279,
      "commit_id" => commit,
      "status" => "passed",
      "counts" => {
        "notstarted" => 0,
        "started" => 0,
        "passed" => 234.0,
        "failed" => 0.0,
        "pending" => 3.0,
        "skipped" => 0.0,
        "error" => 0.0
      },
      "workers" => 24,
      "branch" => "production",
      "ref" => "refs/head/production",
      "repository" => {
        "name" => "repo_name",
        "url" => "git://project/repo",
        "org_name" => "organization_name"
      },
      "xid" => "372da4f69"
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all
    project.webhooks.create!(stage: stages(:test_staging), branch: "production", source: 'tddium')
    stub_github_api(
      "repos/organization_name/repo_name/commits/#{commit}",
      commit: {message: commit_message}
    )
  end

  test_regular_commit "Tddium", no_mapping: {branch: "foobar"}, failed: {status: "failed"}

  it_ignores_skipped_commits

  it_deploys "when github request for commit to check if we should skip fails" do
    GITHUB.expects(:commit).raises(Octokit::Error)
  end
end
