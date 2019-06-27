# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Environment do
  describe '.new' do
    it 'saves' do
      env = Environment.new(name: 'test deploy name', production: true)
      assert_valid(env)
      env.save.must_equal true
      env.reload.name.must_equal 'test deploy name'
      env.production.must_equal true
    end

    it 'default false for production' do
      env = Environment.new(name: 'foo')
      assert_valid(env)
      env.save.must_equal true
      env.reload.name.must_equal 'foo'
      env.production.must_equal false
    end
  end

  describe ".env_deploy_group_array" do
    it "includes All" do
      all = Environment.env_deploy_group_array
      all.map! { |name, value| [name, value&.sub(/-\d+/, '-X')] }
      all.must_equal(
        [
          ["All", nil],
          ["Production", "Environment-X"],
          ["Staging", "Environment-X"],
          ["----", "disabled"],
          ["Pod1", "DeployGroup-X"],
          ["Pod2", "DeployGroup-X"],
          ["Pod 100", "DeployGroup-X"]
        ]
      )
    end

    it "does not includes All when requested" do
      Environment.env_deploy_group_array(include_all: false).wont_include ["All", nil]
    end
  end

  describe 'validations' do
    it 'fail with no name' do
      env = Environment.new(name: nil)
      refute_valid(env)
    end

    it 'fail with non-unique name' do
      env = Environment.new(name: 'Production')
      refute_valid(env)
    end
  end

  describe "#soft_delete" do
    it "refuses when groups are used" do
      refute environments(:production).soft_delete(validate: false)
    end

    it "deletes unused deploy groups" do
      DeployGroupsStage.delete_all
      assert environments(:production).soft_delete(validate: false)
      assert DeployGroup.with_deleted { DeployGroup.find(deploy_groups(:pod1).id) }.deleted_at
    end
  end

  describe '#template_stages' do
    let(:env) { environments(:staging) }

    it 'finds the template stages' do
      refute env.template_stages.empty?
    end
  end

  describe "#locked_by?" do
    def lock(overrides = {})
      @lock ||= Lock.create!({user: users(:deployer), resource: environment}.merge(overrides))
    end

    let(:environment) { environments(:staging) }

    it 'returns true for environment lock' do
      lock # trigger lock creation
      Lock.send :all_cached
      assert_sql_queries 0 do
        environment.locked_by?(lock).must_equal true
      end
    end

    it 'returns false for different project lock' do
      lock(resource: projects(:other))
      Lock.send :all_cached
      assert_sql_queries 0 do
        environment.locked_by?(lock).must_equal false
      end
    end
  end
end
