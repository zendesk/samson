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
end

