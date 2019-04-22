# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Cluster do
  let(:cluster) { create_kubernetes_cluster }

  before { Kubernetes::Cluster.any_instance.stubs(:connection_valid?).returns(true) }

  describe 'validations' do
    it "is valid" do
      assert_valid cluster
    end

    describe "test_client_connection" do
      before { Kubernetes::Cluster.any_instance.unstub(:connection_valid?) }

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

      it "is invalid with unsupported auth_method" do
        cluster.auth_method = "wut"
        refute_valid cluster
      end

      describe "auth_method context" do
        def cluster(attributes = {})
          create_kubernetes_cluster(attributes)
        end

        it "is invalid without config_context" do
          refute_valid cluster(config_context: "")
        end

        it "is invalid when context is not in file" do
          refute_valid cluster(config_context: 'nope')
        end

        it "is invalid without config_filepath" do
          refute_valid cluster(config_filepath: "")
        end

        it "is invalid when config file does not exist" do
          refute_valid cluster(config_filepath: 'nope')
        end
      end

      describe "auth_method database" do
        def cluster(attributes = {})
          create_kubernetes_cluster(
            {auth_method: "database", api_endpoint: "http://foobar.server"}.merge(attributes)
          )
        end

        it "is valid" do
          body = {versions: ['v1']}.to_json
          assert_request(:get, "http://foobar.server/api", to_return: {body: body}) do
            assert_valid cluster
          end
        end

        it "is invalid without api_endpoint" do
          refute_valid cluster(api_endpoint: "")
        end

        it "is invalid with bad api_context" do
          refute_valid cluster(api_endpoint: "wut")
        end

        it "is invalid with invalid cert" do
          refute_valid cluster(client_cert: "wut")
        end

        it "is invalid with invalid key" do
          refute_valid cluster(client_key: "wut")
        end
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

    it 'caches per thread to avoid race conditions of method definition' do
      cluster.client('v1').object_id.wont_equal Thread.new { cluster.client('v1').object_id }.value
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

  describe "#config_contexts" do
    before { cluster.instance_variable_set(:@kubeconfig, nil) }

    it "shows available contexts" do
      cluster.config_contexts.must_equal ["test"]
    end

    it "shows empty when file is not set" do
      cluster.config_filepath = ""
      cluster.config_contexts.must_equal []
    end

    it "shows empty when file is invalid" do
      cluster.config_filepath = "Gemfile"
      cluster.config_contexts.must_equal []
    end
  end

  describe "#as_json" do
    it "does not leak secrets" do
      cluster.as_json.keys.must_equal(
        [
          "id", "name", "description", "config_filepath", "config_context", "created_at", "updated_at", "ip_prefix",
          "auth_method", "api_endpoint", "verify_ssl"
        ]
      )
    end
  end
end
