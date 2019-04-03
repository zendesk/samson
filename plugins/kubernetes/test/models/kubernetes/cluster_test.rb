# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Cluster do
  let(:cluster) { create_kubernetes_cluster }

  describe 'validations' do
    it "is valid" do
      assert_valid cluster
    end

    describe "test_client_connection" do
      before { cluster.class.any_instance.unstub(:connection_valid?) }

      it "is valid" do
        body = {versions: ['v1']}.to_json
        assert_request(:get, "http://foobar.server/api", to_return: {body: body}) do
          assert_valid cluster
        end
      end

      it "is invalid when api version is wrong" do
        assert_request(:get, "http://foobar.server/api", to_return: {body: '{}'}) do
          refute_valid cluster
        end
      end

      it "is invalid when api is dead" do
        assert_request(:get, "http://foobar.server/api", to_return: {status: 404}) do
          refute_valid cluster
        end
      end

      it "is invalid when config file does not exist" do
        cluster.config_filepath = 'nope'
        refute_valid cluster
      end

      it "is invalid when context is not in file" do
        cluster.config_context = 'nope'
        refute_valid cluster
      end
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
      cluster.client('v1').must_be_kind_of Kubeclient::Client
    end

    it 'caches' do
      cluster.client('v1').object_id.must_equal cluster.client('v1').object_id
    end

    it 'can build for other types' do
      cluster.client('policy/v1beta1').api_endpoint.to_s.must_equal 'http://foobar.server/apis'
    end
  end

  describe "#namespaces" do
    it 'ignores kube-system because it is internal and should not be deployed too' do
      items = [{metadata: {name: 'N1'}}, {metadata: {name: 'N2'}}, {metadata: {name: 'kube-system'}}]
      assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {body: {items: items,}.to_json}) do
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

  describe '#server_version' do
    it 'caches the clusters server version' do
      assert_request :get, 'http://foobar.server/version', to_return: {body: '{"gitVersion": "v1.6.0"}'}, times: 1 do
        cluster.server_version
        Rails.cache.read(cluster.cache_key).must_equal '1.6.0' # cache correctly set
        cluster.server_version
      end
    end

    it 'returns the server version as a Gem::Version object' do
      result = cluster.server_version
      result.must_be_instance_of Gem::Version
      result.version.must_equal '1.5.0'
    end

    it 'retries when on random errors' do
      Samson::Retry.expects(:sleep)
      replies = [{status: 404}, {body: '{"gitVersion": "v1.6.0"}'}]
      assert_request :get, 'http://foobar.server/version', to_return: replies, times: 2 do
        cluster.server_version
        Rails.cache.read(cluster.cache_key).must_equal '1.6.0' # cache correctly set
        cluster.server_version
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
