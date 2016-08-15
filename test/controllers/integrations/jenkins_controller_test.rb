# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

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

  options = {
    no_mapping: {build: { scm: { branch: "foobar" }}}, failed: {build: { status: "FAILURE" }}
  }
  test_regular_commit "Jenkins", options do
    project.webhooks.create!(stage: stages(:test_staging), branch: "origin/dev", source: 'jenkins')
  end
end
