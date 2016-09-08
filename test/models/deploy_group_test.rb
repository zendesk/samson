# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 3

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
    let(:deploy_group) { DeployGroup.new(name: 'sfsdf', environment: environment) }

    it 'is valid' do
      assert_valid deploy_group
    end

    it 'require a name' do
      deploy_group.name = nil
      refute_valid(deploy_group)
    end

    it 'require an environment' do
      deploy_group.environment = nil
      refute_valid(deploy_group)
    end

    it 'require a unique name' do
      deploy_group.name = deploy_groups(:pod1).name
      refute_valid(deploy_group)
    end

    describe 'env values' do
      it 'fills empty env values' do
        deploy_group.env_value = ''
        assert_valid(deploy_group)
      end

      it 'does not allow invalid env values' do
        deploy_group.env_value = 'no oooo'
        refute_valid(deploy_group)
      end

      it 'does not allow env values that start weird' do
        deploy_group.env_value = '-nooo'
        refute_valid(deploy_group)
      end

      it 'does not allow env values that start weird' do
        deploy_group.env_value = '-nooo'
        refute_valid(deploy_group)
      end

      it 'does not allow env values that end weird' do
        deploy_group.env_value = 'nooo-'
        refute_valid(deploy_group)
      end

      it 'allows :' do
        deploy_group.env_value = 'y:es'
        assert_valid(deploy_group)
      end
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
      DeployGroup.create!(name: 'Pod666 - the best', environment: environment).env_value.must_equal 'pod666-the-best'
    end

    it 'can set env_value' do
      DeployGroup.create!(name: 'Pod666 - the best', env_value: 'pod:666', environment: environment).env_value.
        must_equal 'pod:666'
    end
  end

  describe '#natural_order' do
    def sort(list)
      list.map { |n| DeployGroup.new(name: n) }.sort_by(&:natural_order).map(&:name)
    end

    it "sorts mixed" do
      sort(['a11', 'a1', 'a22', 'b1', 'a12', 'a9']).must_equal ['a1', 'a9', 'a11', 'a12', 'a22', 'b1']
    end

    it "sorts pure numbers" do
      sort(['11', '1', '22', '12', '9']).must_equal ['1', '9', '11', '12', '22']
    end

    it "sorts pure words" do
      sort(['bb', 'ab', 'aa', 'a', 'b']).must_equal ['a', 'aa', 'ab', 'b', 'bb']
    end
  end

  it_expires_stage :save
  it_expires_stage :destroy
  it_expires_stage :soft_delete

  describe "#destroy_deploy_groups_stages" do
    let(:deploy_group) { deploy_groups(:pod100) }

    it 'deletes deploy_groups_stages on destroy' do
      assert_difference 'DeployGroupsStage.count', -1 do
        deploy_group.destroy!
      end
    end
  end

  describe "#template_stages" do
    let(:deploy_group) { deploy_groups(:pod100) }

    it "returns all template_stages for the deploy_group" do
      refute deploy_group.template_stages.empty?
    end
  end
end
