# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::SemaphoreController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:commit_message) { "Update 'shoulda' gem." }
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
        "message" => commit_message,
        "timestamp" => "2012-07-04T18:14:08Z"
      }
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'semaphore')
  end

  test_regular_commit "Semaphore", failed: {result: "failed"}, no_mapping: {branch_name: "foobar"}

  it_ignores_skipped_commits
end
