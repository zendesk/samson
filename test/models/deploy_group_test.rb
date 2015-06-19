require_relative '../test_helper'

describe DeployGroup do
  let(:stage) { stages(:test_staging) }
  let(:environment) { environments(:production) }
  let(:deploy_group) { deploy_groups(:pod1) }

  def self.it_expires_stage(method)
    it "expires stages when #{method}" do
      stage.deploy_groups << deploy_group
      stage.update_column(:updated_at, 1.minute.ago)
      old = stage.updated_at.to_s(:db)
      deploy_group.send(method)
      stage.reload.updated_at.to_s(:db).wont_equal old
    end
  end

  describe '.new' do
    it 'saves' do
      deploy_group = DeployGroup.new(name: 'test deploy name', environment: environment)
      assert_valid(deploy_group)
    end
  end

  describe 'validations' do
    it 'require a name' do
      deploy_group = DeployGroup.new(name: nil, environment: environment)
      refute_valid(deploy_group)
    end

    it 'require an environment' do
      deploy_group = DeployGroup.new(name: 'foo')
      refute_valid(deploy_group)
    end

    it 'require a unique name' do
      deploy_group = DeployGroup.new(name: 'Pod1', environment: environment)
      refute_valid(deploy_group)
    end
  end

  it 'queried by environment' do
    env = Environment.create!(name: 'env666')
    dg1 = DeployGroup.create!(name: 'Pod666', environment: env)
    dg2 = DeployGroup.create!(name: 'Pod667', environment: env)
    DeployGroup.create!(name: 'Pod668', environment: environment)
    env.deploy_groups.must_equal [dg1, dg2]
  end

  describe "#initialize_env_value" do
    it 'prefils env_value' do
      DeployGroup.create!(name: 'Pod666 - the best', environment: environment).env_value.must_equal 'Pod666 - the best'
    end

    it 'can set env_value' do
      DeployGroup.create!(name: 'Pod666 - the best', env_value: 'pod:666', environment: environment).env_value.must_equal 'pod:666'
    end
  end

  it_expires_stage :save
  it_expires_stage :destroy
  it_expires_stage :soft_delete
end
