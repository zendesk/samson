# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroup do
  let(:deploy_group) { deploy_groups(:pod1) }

  describe "cluster_deploy_group" do
    it "accepts nested attributes" do
      group = DeployGroup.new(cluster_deploy_group_attributes: {namespace: 'Foo', kubernetes_cluster_id: 1})
      group.cluster_deploy_group.namespace.must_equal "Foo"
    end

    it "does not accept attributes from a form if kubernetes_cluster_id was left blank" do
      group = DeployGroup.new(cluster_deploy_group_attributes: {namespace: 'Foo'})
      refute group.cluster_deploy_group
    end

    describe "with existing group" do
      let(:deploy_group) { deploy_groups(:pod1) }
      let(:cdg) { deploy_group.create_cluster_deploy_group!(namespace: 'foo', kubernetes_cluster_id: 1) }

      before { Kubernetes::ClusterDeployGroup.any_instance.stubs(:valid?).returns(true) }

      it "deletes connection when user sets cluster to empty" do
        deploy_group.cluster_deploy_group_attributes = {id: cdg.id, namespace: 'Foo'}
        deploy_group.save!
        assert_raises(ActiveRecord::RecordNotFound) { deploy_group.cluster_deploy_group.reload }
      end

      it "can update" do
        deploy_group.cluster_deploy_group_attributes = {id: cdg.id, kubernetes_cluster_id: 2, namespace: 'Foo'}
        deploy_group.save!
        deploy_group.reload.cluster_deploy_group.kubernetes_cluster_id.must_equal 2
      end
    end
  end

  describe "#kubernetes_namespace" do
    let(:deploy_group100) { deploy_groups(:pod100) }
    let(:group) { kubernetes_cluster_deploy_groups(:pod1) }

    it "fetches the namespace from cluster" do
      deploy_group.kubernetes_namespace.must_equal group.namespace
    end

    it "returns nil when cluster is missing" do
      refute deploy_group100.kubernetes_namespace
    end
  end

  describe "#delete_kubernetes_deploy_group_roles" do
    let(:group_role) { kubernetes_deploy_group_roles(:test_pod1_app_server) }

    it "destroys deploy_group_roles after soft delete" do
      deploy_group.deploy_groups_stages.clear
      refute_empty deploy_group.kubernetes_deploy_group_roles
      deploy_group.soft_delete!(validate: false)
      assert_empty deploy_group.reload.kubernetes_deploy_group_roles
    end
  end
end
