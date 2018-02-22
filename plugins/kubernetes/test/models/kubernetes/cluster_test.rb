# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Cluster do
  let(:cluster) { create_kubernetes_cluster }

  describe 'validations' do
    it "is valid" do
      assert_valid cluster
    end

    it "is invalid when api version is wrong" do
      cluster.class.any_instance.unstub(:connection_valid?)
      assert_request(:get, "http://foobar.server/api", to_return: {body: '{}'}) do
        refute_valid cluster
      end
    end

    it "is invalid when api is dead" do
      cluster.class.any_instance.unstub(:connection_valid?)
      assert_request(:get, "http://foobar.server/api", to_return: {status: 404}) do
        refute_valid cluster
      end
    end

    it "is invalid when config file does not exist" do
      cluster.config_filepath = 'nope'
      refute_valid cluster
    end

    describe "ip_prefix" do
      it "is valid with 1" do
        cluster.ip_prefix = '123'
        assert_valid cluster
      end

      it "is valid with 3" do
        cluster.ip_prefix = '123.123.123'
        assert_valid cluster
      end

      it "is invalid with bad values" do
        cluster.ip_prefix = '12312.'
        refute_valid cluster
      end

      it "is invalid with trailing ." do
        cluster.ip_prefix = '123.'
        refute_valid cluster
      end

      it "is invalid with 4" do
        cluster.ip_prefix = '123.123.123.123'
        refute_valid cluster
      end
    end
  end

  describe '#client' do
    it 'creates a client' do
      cluster.client.must_be_kind_of Kubeclient::Client
    end
  end

  describe '#extension_client' do
    it 'creates a client' do
      cluster.extension_client.must_be_kind_of Kubeclient::Client
    end
  end

  describe '#autoscaling_client' do
    it 'creates a client' do
      cluster.autoscaling_client.must_be_kind_of Kubeclient::Client
    end
  end

  describe '#apps_client' do
    it 'creates a client' do
      cluster.apps_client.must_be_kind_of Kubeclient::Client
    end
  end

  describe '#batch_client' do
    it 'creates a client' do
      cluster.batch_client.must_be_kind_of Kubeclient::Client
    end
  end

  describe "#namespaces" do
    it 'ignores kube-system because it is internal and should not be deployed too' do
      items = [{metadata: {name: 'N1'}}, {metadata: {name: 'N2'}}, {metadata: {name: 'kube-system'}}]
      assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {body: {items: items, }.to_json}) do
        cluster.namespaces.must_equal ['N1', 'N2']
      end
    end
  end

  describe "#schedulable_nodes" do
    def stub_response
      stub_request(:get, "http://foobar.server/api/v1/nodes").to_return(body: {items: nodes}.to_json)
    end

    let(:nodes) do
      [
        {id: 0, spec: {unschedulable: false}, metadata: {labels: {"node-type": "node"}}},
        {id: 1, spec: {unschedulable: false}, metadata: {labels: {"node-type": "node"}}},
        {id: 2, spec: {unschedulable: false}, metadata: {labels: {"node-type": "node"}}}
      ]
    end

    it "finds all nodes" do
      stub_response
      cluster.schedulable_nodes.map { |n| n[:id] }.must_equal [0, 1, 2]
    end

    it "excludes unscheduleable" do
      nodes[1][:spec][:unschedulable] = true
      stub_response
      cluster.schedulable_nodes.map { |n| n[:id] }.must_equal [0, 2]
    end

    it "does not blow up on connection issues" do
      assert_request(:get, "http://foobar.server/api/v1/nodes", to_timeout: []) do
        cluster.schedulable_nodes.must_equal []
      end
    end
  end

  describe "#ensure_unused" do
    it "does not destroy used" do
      Kubernetes::ClusterDeployGroup.any_instance.stubs(:validate_namespace_exists)
      cluster.cluster_deploy_groups.create! deploy_group: deploy_groups(:pod100), namespace: 'foo'

      refute cluster.destroy
      cluster.errors.full_messages.must_equal ["Cannot be deleted since it is currently used by Pod 100."]
    end

    it "destroys when unused" do
      assert cluster.destroy
      cluster.errors.full_messages.must_equal []
    end
  end
end
