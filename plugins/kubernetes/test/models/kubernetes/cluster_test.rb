require_relative "../../test_helper"

SingleCov.covered! uncovered: 11

describe Kubernetes::Cluster do
  let(:cluster) { Kubernetes::Cluster.create!(name: 'Foo', config_filepath: __FILE__, config_context: 'y') }

  before do
    Kubernetes::Cluster.any_instance.stubs(connection_valid?: true)
  end

  describe "#watch!" do
    it "watches" do
      Watchers::ClusterPodErrorWatcher.expects(:restart_watcher)
      Watchers::ClusterPodWatcher.expects(:restart_watcher)
      cluster.watch!
    end
  end
end

