# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  describe "#validate_deploy_groups_have_a_cluster" do
    let(:stage) { stages(:test_staging) }

    it "is valid" do
      assert_valid stage
    end

    describe "when on kubernetes" do
      before { stage.kubernetes = true }

      it "is not valid when on kubernetes but deploy groups do not know their cluster" do
        refute_valid stage
        stage.errors.full_messages.must_equal [
          "Kubernetes Deploy groups need to have a cluster associated, but Pod 100 did not."
        ]
      end

      it "is not valid when on kubernetes but deploy groups do not know their cluster" do
        Kubernetes::Cluster.any_instance.stubs(connection_valid?: true, namespaces: ['staging'])
        stage.deploy_groups.each do |dg|
          dg.create_cluster_deploy_group cluster: kubernetes_clusters(:test_cluster), namespace: 'staging'
        end
        assert_valid stage
      end

      it "is not valid when using non-kubernetes rollback" do
        stage.allow_redeploy_previous_when_failed = true
        refute_valid stage
      end
    end
  end

  describe "#kubernetes_stage_roles" do
    it "accepts attributes" do
      stage = Stage.new(
        kubernetes_stage_roles_attributes: {0 => {kubernetes_role_id: kubernetes_roles(:app_server).id, ignored: true}}
      )
      stage.kubernetes_stage_roles.size.must_equal 1
    end

    it "ignores blank attributes" do
      stage = Stage.new(
        kubernetes_stage_roles_attributes: {0 => {kubernetes_role_id: "", ignored: true}}
      )
      stage.kubernetes_stage_roles.size.must_equal 0
    end
  end

  describe "#seed_kubernetes_roles" do
    let(:stage) do
      stage = stages(:test_staging).dup
      stage.name = 'Another'
      stage.permalink = nil
      stage
    end

    it "does nothing" do
      Kubernetes::Role.expects(:seed!).never
      stage.save!
    end

    describe "when kubernetes is set" do
      before { stage.kubernetes = true }

      it "calls seed to fill in missing roles (most useful for new projects)" do
        Kubernetes::Role.expects(:seed!)
        stage.save!
      end

      it "does not blow up when seeding fails, users can fix this later" do
        Kubernetes::Role.expects(:seed!).raises(Samson::Hooks::UserError)
        stage.save!
      end
    end
  end

  describe "#clear_commands" do
    it "clears commands" do
      stage = stages(:test_staging)
      stage.update_attribute(:kubernetes, true)
      stage.reload.script.must_equal ""
    end
  end
end
