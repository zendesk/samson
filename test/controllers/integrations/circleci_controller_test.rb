# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::CircleciController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }
  let(:commit_message) { "Don't explode when the system clock shifts backwards" }
  let(:payload) do
    {
      "payload" => {
        "vcs_url" => "https://github.com/circleci/mongofinil",
        "build_url" => "https://circleci.com/gh/circleci/mongofinil/22",
        "build_num" => 22,
        "branch" => "master",
        "vcs_revision" => commit,
        "committer_name" => "Allen Rohner",
        "committer_email" => "arohner@gmail.com",
        "subject" => commit_message,
        "body" => "",
        "why" => "github",
        "dont_build" => nil,
        "queued_at" => "2013-02-12T21:33:30Z",
        "start_time" => "2013-02-12T21:33:38Z",
        "stop_time" => "2013-02-12T21:34:01Z",
        "build_time_millis" => 23505,
        "username" => "circleci",
        "reponame" => "mongofinil",
        "lifecycle" => "finished",
        "outcome" => "success",
        "status" => "success",
        "retry_of" => nil,
      }
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'circleci')
  end

  test_regular_commit "Circleci", failed: {payload: {status: "failed"}}, no_mapping: {payload: {branch: "foobar"}}

  it_ignores_skipped_commits
end
