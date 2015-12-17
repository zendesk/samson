module Watchers
  class ClusterPodErrorWatcher < BaseClusterWatcher
    include Celluloid::Notifications

    def initialize(cluster)
      super(cluster.client.watch_events(field_selector: 'involvedObject.kind=Pod'))
      @cluster = cluster
    end

    private

    attr_reader :cluster

    def handle_notice(notice)
      event = Events::ClusterEvent.new(notice)

      if pod_error?(event)
        pod = get_pod(event.involved_object)
        publish(Watchers::TopicSubscription.pod_updates_topic(pod.project_id), message(event, pod: pod)) unless pod.nil?
      end
    end

    def get_pod(involved_object)
      api_pod = cluster.client.get_pod(involved_object.name, involved_object.namespace)
      Kubernetes::Api::Pod.new(api_pod)
    rescue KubeException => e
      warn e.to_s
      nil
    end

    def pod_error?(event)
      downcase(event.reason) == 'failed' || downcase(event.reason) == 'failedscheduling'
    end

    def downcase(reason)
      reason.try(:downcase)
    end
  end
end
