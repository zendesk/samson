module Watchers
  class ClusterPodWatcher < BaseClusterWatcher
    include Celluloid::Notifications

    def initialize(cluster)
      super(cluster.client.watch_pods)
    end

    private

    def handle_notice(notice)
      pod_event = Events::PodEvent.new(notice)

      if pod_event.valid?
        pod = pod_event.pod
        publish(Watchers::TopicSubscription.pod_updates_topic(pod.project_id), message(pod_event)) if pod.valid?
      else
        error("Invalid Kubernetes event: #{notice}")
      end
    end
  end
end
