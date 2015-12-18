module Watchers
  class ClusterPodWatcher < BaseClusterWatcher
    include Celluloid::Notifications

    def initialize(client)
      super(client.watch_pods)
    end

    private

    def handle_notice(notice)
      if notice.object.metadata.labels
        rc_name = notice.object.metadata.labels['replication_controller']
        publish(rc_name, notice) if rc_name
      end
    end
  end
end
