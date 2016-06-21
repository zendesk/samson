require_relative "../../test_helper"

SingleCov.covered! uncovered: 6

describe Kubernetes::Cluster do
  let(:cluster) { create_kubernetes_cluster }

  describe 'clients' do
    it 'can create a basic client' do
      cluster.client.must_be_kind_of Kubeclient::Client
    end

    it 'can create an extensions client' do
      cluster.extension_client.must_be_kind_of Kubeclient::Client
    end
  end
end
