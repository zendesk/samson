module Watchers
  class ClusterPodErrorWatcher < BaseClusterWatcher
    include Celluloid::Notifications

    def initialize(client)
      @client = client
      super(@client.watch_events(field_selector: 'involvedObject.kind=Pod'))
    end

    private

    def handle_notice(notice)
      if error_notice?(notice.object.reason)
        rc_name = rc_name(notice.object.involvedObject)
        publish(rc_name, notice) if rc_name
      end
    end

    def rc_name(involved_object)
      pod = @client.get_pod(involved_object.name, involved_object.namespace)
      pod.metadata.labels ? pod.metadata.labels.replication_controller : nil
    rescue KubeException => e
      if e.error_code == 404
        warn e.to_s
        nil
      else
        raise
      end
    end

    def error_notice?(reason)
      reason == 'failed' || reason == 'failedScheduling'
    end
  end
end
