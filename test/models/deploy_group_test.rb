require_relative '../test_helper'

describe DeployGroup do
  let(:prod_env) { environments(:production) }

  describe '.new' do
    it 'saves' do
      deploy_group = DeployGroup.new(name: 'test deploy name', environment: prod_env)
      assert_valid(deploy_group)
    end
  end

  describe 'validations' do
    it 'require a name' do
      deploy_group = DeployGroup.new(name: nil, environment: prod_env)
      refute_valid(deploy_group)
    end

    it 'require an environment' do
      deploy_group = DeployGroup.new(name: 'foo')
      refute_valid(deploy_group)
    end

    it 'require a unique name' do
      deploy_group = DeployGroup.new(name: 'Pod1', environment: prod_env)
      refute_valid(deploy_group)
    end
  end

  it 'queried by environment' do
    env = Environment.create!(name: 'env666')
    dg1 = DeployGroup.create!(name: 'Pod666', environment: env)
    dg2 = DeployGroup.create!(name: 'Pod667', environment: env)
    DeployGroup.create!(name: 'Pod668', environment: prod_env)
    env.deploy_groups.must_equal [dg1, dg2]
  end
end
