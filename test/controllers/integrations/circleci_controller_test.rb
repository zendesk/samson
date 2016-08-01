require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::CircleciController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }
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
        "subject" => "Don't explode when the system clock shifts backwards",
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

  before { Deploy.delete_all }

  test_regular_commit "Circleci", failed: {payload: {status: "failed"}}, no_mapping: {payload: {branch: "foobar"}} do
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'circleci')
  end

  describe "skipping" do
    it "doesn't trigger a deploy if we want to skip with [deploy skip]" do
      payload["payload"]["subject"] = "[deploy skip]"
      project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'circleci')
      post :create, payload.merge(token: project.token)

      project.deploys.must_equal []
    end

    it "doesn't trigger a deploy if we want to skip with [skip deploy]" do
      payload["payload"]["subject"] = "[skip deploy]"
      project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'circleci')
      post :create, payload.merge(token: project.token)

      project.deploys.must_equal []
    end
  end
end
