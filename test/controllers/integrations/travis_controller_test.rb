# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::TravisController do
  extend IntegrationsControllerTestHelper

  def post(_action, **options)
    options[:params][:payload] = options[:params][:payload].to_json
    super
  end

  let(:commit) { "123abc" }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:user) { users(:deployer) }
  let(:commit_message) { 'A change' }
  let(:payload) do
    {
      payload: {
        status_message: 'Passed',
        branch: 'master',
        message: commit_message,
        committer_email: user.email,
        commit: commit,
        type: 'push'
      }
    }.with_indifferent_access
  end

  before do
    Deploy.delete_all
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'travis')
  end

  test_regular_commit "Travis", no_mapping: {payload: {branch: "foo"}}, failed: {payload: {status_message: 'Failure'}}

  it_deploys "with status_message 'Fixed'" do
    payload[:payload][:status_message] = 'Fixed'
  end

  it_ignores_skipped_commits
end
