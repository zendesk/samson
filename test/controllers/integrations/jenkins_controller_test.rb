require_relative '../../test_helper'

describe Integrations::JenkinsController do
  extend IntegrationsControllerTestHelper

  let(:commit) { "dc395381e650f3bac18457909880829fc20e34ba" }
  let(:project) { projects(:test) }

  let(:payload) do
    {
      build: {
        status: "SUCCESS",
        scm: {
          commit: 'dc395381e650f3bac18457909880829fc20e34ba',
          branch: 'origin/dev'
        }
      }
    }.with_indifferent_access
  end

  before { Deploy.delete_all }

  test_regular_commit "Jenkins", no_mapping: {build: { scm: { branch: "foobar" }}}, failed: {build: { status: "FAILURE" }} do
    project.webhooks.create!(stage: stages(:test_staging), branch: "origin/dev", source: 'jenkins')
  end
end
