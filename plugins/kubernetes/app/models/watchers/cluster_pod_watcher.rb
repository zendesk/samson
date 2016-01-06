module Watchers
  class ClusterPodWatcher < BaseClusterWatcher
    include Celluloid::Notifications

    def initialize(client)
      super(client.watch_pods)
    end

    private

    def handle_notice(notice)
      if notice.object.metadata.labels
        project = notice.object.metadata.labels['project']
        publish(project, notice) if project
      end
    end
  end
end
