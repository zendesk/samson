require_relative '../../test_helper'

describe Integrations::SemaphoreController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }
  let(:payload) do
    {
      "branch_name" => "master",
      "branch_url" => "https://semaphoreapp.com/projects/44/branches/50",
      "project_name" => "base-app",
      "build_url" => "https://semaphoreapp.com/projects/44/branches/50/builds/15",
      "build_number" => 15,
      "result" => "passed",
      "started_at" => "2012-07-09T15:23:53Z",
      "finished_at" => "2012-07-09T15:30:16Z",
      "commit" => {
        "id" => commit,
        "url" => "https://github.com/renderedtext/base-app/commit/dc395381e650f3bac18457909880829fc20e34ba",
        "author_name" => "Vladimir Saric",
        "author_email" => "vladimir@renderedtext.com",
        "message" => "Update 'shoulda' gem.",
        "timestamp" => "2012-07-04T18:14:08Z"
      }
    }.with_indifferent_access
  end

  before { Deploy.delete_all }

  test_regular_commit "Semaphore", failed: {result: "failed"}, no_mapping: {branch_name: "foobar"} do
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'semaphore')
  end

  describe "skipping" do
    let(:payload) do
      {
        "branch_name" => "master",
        "branch_url" => "https://semaphoreapp.com/projects/44/branches/51",
        "project_name" => "base-app",
        "build_url" => "https://semaphoreapp.com/projects/44/branches/51/builds/15",
        "build_number" => 16,
        "result" => "passed",
        "started_at" => "2012-07-10T15:23:53Z",
        "finished_at" => "2012-07-10T15:30:16Z",
        "commit" => {
          "id" => commit,
          "url" => "https://github.com/renderedtext/base-app/commit/dc395381e650f3bac18457909880829fc20e34ba",
          "author_name" => "Vladimir Saric",
          "author_email" => "vladimir@renderedtext.com",
          "message" => "[deploy skip]",
          "timestamp" => "2012-07-05T18:14:08Z"
        }
      }.with_indifferent_access
    end

    it "doesn't trigger a deploy if we want to skip with [deploy skip]" do
      payload["commit"]["message"] = "[deploy skip]"
      project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'semaphore')
      post :create, payload.merge(token: project.token)

      project.deploys.must_equal []
    end

    it "doesn't trigger a deploy if we want to skip with [skip deploy]" do
      payload["commit"]["message"] = "[skip deploy]"
      project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'semaphore')
      post :create, payload.merge(token: project.token)

      project.deploys.must_equal []
    end
  end
end

