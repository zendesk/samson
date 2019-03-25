# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroup do
  let(:stage) { stages(:test_staging) }
  let(:environment) { environments(:production) }
  let(:deploy_group) { deploy_groups(:pod1) }

  describe '.enabled?' do
    it 'is enabled when DEPLOY_GROUP_FEATURE is present' do
      with_env DEPLOY_GROUP_FEATURE: "1" do
        DeployGroup.enabled?.must_equal true
      end
    end

    it 'is disabled when DEPLOY_GROUP_FEATURE is blank' do
      DeployGroup.enabled?.must_equal false
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

  describe "#soft_delete" do
    it 'does not allow deleting while still being used' do
      refute deploy_group.soft_delete(validate: false)
    end

    it 'allows deleting while not being used' do
      deploy_group.deploy_groups_stages.delete_all
      assert deploy_group.soft_delete!(validate: false)
    end
  end

  it 'queried by environment' do
    env = Environment.create!(name: 'env666')
    dg1 = DeployGroup.create!(name: 'Pod666', environment: env)
    dg2 = DeployGroup.create!(name: 'Pod667', environment: env)
    DeployGroup.create!(name: 'Pod668', environment: environment)
    env.deploy_groups.sort.must_equal [dg1, dg2].sort
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

  describe "#generated_name_sortable" do
    it "sets value" do
      group = DeployGroup.create!(name: "Pod666 - the best", environment: environment)
      group.name_sortable.must_equal "Pod00666 - the best"
    end
  end

  it "expires stages when saving" do
    stage.deploy_groups << deploy_group
    stage.update_column(:updated_at, 1.minute.ago)
    old = stage.updated_at.to_s(:db)
    deploy_group.save!
    stage.reload.updated_at.to_s(:db).wont_equal old
  end

  describe "#template_stages" do
    let(:deploy_group) { deploy_groups(:pod100) }

    it "returns all template_stages for the deploy_group" do
      refute deploy_group.template_stages.empty?
    end
  end

  describe "#validate_vault_server_has_same_environment" do
    let(:server) { create_vault_server }

    before do
      Samson::Secrets::VaultServer.any_instance.stubs(:validate_cert)
      deploy_groups(:pod1).update_attributes!(vault_server: server)
      server.reload
    end

    it "is valid when vault servers have exclusive environments" do
      assert deploy_groups(:pod2).update_attributes(vault_server: server)
    end

    it "is valid when not changing invalid vault_server_id so nested saves do not blow up" do
      deploy_groups(:pod100).update_column(:vault_server_id, server.id)
      deploy_groups(:pod100).save!
    end

    it "is invalid when vault servers mix production and non-production deploy groups" do
      refute deploy_groups(:pod100).update_attributes(vault_server: server)
    end

    it "is valid for 2 different environments, as long as they're both production" do
      other_prod_env = Environment.create!(name: 'Other prod', production: true)
      deploy_group = DeployGroup.create(name: 'Another group', environment: other_prod_env, vault_server: server)
      assert deploy_group.valid?
    end
  end

  describe "#pluck_stage_ids" do
    it "uses 1 cheap query" do
      deploy_group
      queries = assert_sql_queries(1) { deploy_group.pluck_stage_ids.to_a }
      queries.first.wont_include "JOIN"
    end
  end

  describe "#locked_by?" do
    before { deploy_group }

    it "is not locked by other" do
      project = Project.first
      assert_sql_queries 0 do
        refute deploy_group.locked_by?(Lock.new(resource: project))
      end
    end

    it "is locked by self" do
      assert_sql_queries 0 do
        assert deploy_group.locked_by?(Lock.new(resource: deploy_group))
      end
    end

    it "is locked by own environment" do
      assert deploy_group.locked_by?(Lock.new(resource: environment))
    end

    it "is not by locked other environment" do
      refute deploy_group.locked_by?(Lock.new(resource: environments(:staging)))
    end
  end

  describe "#as_json" do
    it "does not render internal read-only column" do
      deploy_group.as_json.keys.wont_include "name_sortable"
    end
  end
end
