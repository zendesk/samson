# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroupSerializer do
  describe 'a deploy group not associated with a kubernetes cluster' do
    let(:deploy_group) { deploy_groups(:pod100) }

    it 'contains only the basic information when serialized' do
      parsed = JSON.parse(DeployGroupSerializer.new(deploy_group).to_json).with_indifferent_access
      parsed[:id].must_equal deploy_group.id
      parsed[:name].must_equal deploy_group.name
      parsed[:kubernetes_cluster].must_be_nil
    end
  end

  describe 'a deploy group associated with a kubernetes cluster' do
    let(:deploy_group) { deploy_groups(:pod1) }
    let(:kubernetes_cluster) { kubernetes_clusters(:test_cluster) }

    before do
      Kubernetes::Cluster.any_instance.expects(:namespace_exists?).returns(true)
      Kubernetes::ClusterDeployGroup.create!(cluster: kubernetes_cluster, deploy_group: deploy_group, namespace: 'pod1')
    end

    it 'contains the kubernetes cluster when serialized' do
      parsed = JSON.parse(DeployGroupSerializer.new(deploy_group).to_json).with_indifferent_access
      cluster = parsed[:kubernetes_cluster]
      cluster[:name].must_equal 'test'
      cluster[:config_filepath].must_equal 'plugins/kubernetes/test/cluster_config.yml'
      cluster[:config_context].must_equal 'test'
    end
  end
end
