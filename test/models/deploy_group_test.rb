require_relative '../test_helper'

describe DeployGroup do
  let(:prod_env) { environments(:production_env) }

  it 'should be saved with valid name/env' do
    deploy_group = DeployGroup.new(name: 'test deploy name', environment: prod_env)
    deploy_group.valid?.must_equal true
    deploy_group.save.must_equal true
  end

  it 'should require a name' do
    deploy_group = DeployGroup.new(name: nil, environment: prod_env)
    deploy_group.valid?.must_equal false
  end

  it 'should require an environment' do
    deploy_group = DeployGroup.new(name: 'foo')
    deploy_group.valid?.must_equal false
  end

  it 'should require a unique name' do
    deploy_group = DeployGroup.new(name: 'Pod1', environment: prod_env)
    deploy_group.valid?.must_equal false
  end

  it 'should be queried by environment' do
    DeployGroup.create!(name: 'Pod666', environment: prod_env)
    DeployGroup.create!(name: 'Pod667', environment: prod_env)
    prod_env.deploy_groups.count.must_equal 4
  end
end
