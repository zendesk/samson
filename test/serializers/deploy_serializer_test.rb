require_relative '../test_helper'

SingleCov.covered!

describe BuildSerializer do
  let(:deploy) { deploys(:succeeded_test) }
  let(:parsed) { JSON.parse(DeploySerializer.new(deploy).to_json) }

  it 'serializes url' do
    parsed['deploy']['url'].must_equal "http://www.test-url.com/projects/foo/deploys/#{deploy.to_param}"
  end

  it 'serializes summary' do
    parsed['deploy']['summary'].must_equal "staging was deployed to Staging"
  end

  it 'serializes created_at to milliseconds' do
    parsed['deploy']['updated_at'].must_equal deploy.updated_at.to_i * 1000
  end
end
