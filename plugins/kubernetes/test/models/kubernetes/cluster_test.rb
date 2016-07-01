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
      stub_request(:get, "http://foobar.server/api").to_return(body: '{}')
      refute_valid cluster
    end

    it "is invalid when api is dead" do
      cluster.class.any_instance.unstub(:connection_valid?)
      stub_request(:get, "http://foobar.server/api").to_return(status: 404)
      refute_valid cluster
    end

    it "is invalid when config file does not exist" do
      cluster.config_filepath = 'nope'
      refute_valid cluster
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

  describe "#namespaces" do
    it 'ignores kube-system' do
      items = [{metadata: {name: 'N1'}}, {metadata: {name: 'N2'}}, {metadata: {name: 'kube-system'}}]
      stub_request(:get, "http://foobar.server/api/v1/namespaces").
        to_return(body: {items: items, }.to_json)
      cluster.namespaces.must_equal ['N1', 'N2']
    end
  end

  describe "#namespace_exists?" do
    it 'is true when it exists' do
      cluster.expects(:namespaces).returns(['a'])
      assert cluster.namespace_exists?('a')
    end

    it "is false when it does not exist" do
      cluster.expects(:namespaces).returns(['b'])
      refute cluster.namespace_exists?('a')
    end

    it "is false api is unreachable" do
      stub_request(:get, "http://foobar.server/api/v1/namespaces").to_return(status: 404)
      refute cluster.namespace_exists?('a')
    end
  end
end
