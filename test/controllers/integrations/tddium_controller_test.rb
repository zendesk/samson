require_relative '../../test_helper'

describe Integrations::TddiumController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
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
    @webhook = project.webhooks.create!(stage: stages(:test_staging), branch: "production", source: 'tddium')
  end

  test_regular_commit "Tddium", no_mapping: {branch: "foobar"}, failed: {status: "failed"} do
    stub_github_api("repos/organization_name/repo_name/commits/dc395381e650f3bac18457909880829fc20e34ba", commit: {message: "hi"})
  end

  it "responds with 200 OK if the token is valid but the repository url is invalid" do
    stub_github_api("commits/dc395381e650f3bac18457909880829fc20e34ba", commit: {message: "hi"})

    post :create, payload.merge(token: project.token, repository: { url: "foobar"} )

    response.status.must_equal 200
  end

  it "doesn't trigger a deploy if the commit message contains [deploy skip]" do
    @webhook.destroy!

    stub_github_api("repos/organization_name/repo_name/commits/dc395381e650f3bac18457909880829fc20e34ba", commit: {message: "hi[deploy skip]"})

    project.webhooks.create!(stage: stages(:test_staging), branch: "production", source: 'tddium')
    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
  end

  it "doesn't trigger a deploy if the commit message contains [skip deploy]" do
    @webhook.destroy!

    stub_github_api("repos/organization_name/repo_name/commits/dc395381e650f3bac18457909880829fc20e34ba", commit: {message: "hi[skip deploy]"})

    project.webhooks.create!(stage: stages(:test_staging), branch: "production", source: 'tddium')
    post :create, payload.merge(token: project.token)

    project.deploys.must_equal []
  end
end
