require_relative "../../test_helper"

SingleCov.covered! uncovered: 11

describe Kubernetes::Cluster do
  let(:cluster) { create_kubernetes_cluster }

  describe "#watch!" do
    it "watches" do
      Watchers::ClusterPodErrorWatcher.expects(:restart_watcher)
      Watchers::ClusterPodWatcher.expects(:restart_watcher)
      cluster.watch!
    end
  end

  describe 'clients' do
    it 'can create a basic client' do
      cluster.client.must_be_kind_of Kubeclient::Client
    end

    it 'can create an extensions client' do
      cluster.extension_client.must_be_kind_of Kubeclient::Client
    end
  end
end
