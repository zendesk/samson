# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::GenericController do
  extend IntegrationsControllerTestHelper

  def payload(overrides = {})
    @payload ||= {
      deploy: {
        commit: {
          sha: commit,
          message: 'Hello world!'
        },
        branch: 'origin/dev'
      }
    }.merge(overrides).with_indifferent_access
  end

  let(:commit) { 'dc395381e650f3bac18457909880829fc20e34ba' }
  let(:project) { projects(:test) }

  before do
    Deploy.delete_all
    project.webhooks.create!(stage: stages(:test_staging), branch: "origin/dev", source: 'generic')
  end

  test_regular_commit "Generic",
    no_mapping: {deploy: {branch: "foobar"}}, failed: nil
end
