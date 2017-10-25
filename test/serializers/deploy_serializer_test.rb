# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeploySerializer do
  let(:deploy) { deploys(:succeeded_test) }
  let(:parsed) { JSON.parse(DeploySerializer.new(deploy).to_json) }

  it 'serializes url' do
    parsed['url'].must_equal "http://www.test-url.com/projects/foo/deploys/#{deploy.to_param}"
  end

  it 'serializes summary' do
    parsed['summary'].must_equal "staging was deployed to Staging"
  end

  it 'serializes created_at' do
    parsed['updated_at'].must_equal '2014-01-01T20:10:00.000Z'
  end

  it 'can serialize with deleted stage' do
    deploy.stage.soft_delete!
    deploy.reload
    parsed
  end
end
