require_relative '../test_helper'

SingleCov.covered!

describe ProjectSerializer do
  let(:project) { projects(:test) }
  let(:parsed) { JSON.parse(ProjectSerializer.new(project).to_json) }

  it 'serializes url' do
    parsed['project']['url'].must_equal "http://www.test-url.com/projects/foo"
  end
end
