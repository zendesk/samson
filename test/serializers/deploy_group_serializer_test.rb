require_relative '../test_helper'

SingleCov.covered!

describe DeployGroupSerializer do
  let(:deploy_group) { deploy_groups(:pod1) }

  it 'serializes the basic information' do
    parsed = JSON.parse(DeployGroupSerializer.new(deploy_group).to_json).with_indifferent_access
    parsed[:deploy_group][:id].must_equal deploy_group.id
    parsed[:deploy_group][:name].must_equal deploy_group.name
  end
end
