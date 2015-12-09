require 'celluloid/current'
require 'celluloid/io'

module Watchers
  class ClusterPodWatcher
    include Celluloid::IO
    include Celluloid::Notifications
    include Celluloid::Internals::Logger

    finalizer :stop_watching

    def initialize(client)
      @client = client
      @watch_stream = nil
      async :start_watching
    end

    def start_watching
      info 'watcher started'
      @watch_stream = @client.watch_pods
      @watch_stream.each do |notice|
        handle_notice notice
      end
    end

    def stop_watching
      info 'watcher stopped'
      if @watch_stream
        @watch_stream.finish
        @watch_stream = nil
      end
    end

    def self.pod_watcher_symbol(cluster)
      "cluster_pod_watcher_#{cluster.id}".to_sym
    end

    def self.start_watcher(cluster)
      watcher_name = pod_watcher_symbol(cluster)
      supervise as: watcher_name, args: [cluster.client]
    end

    def self.restart_watcher(cluster)
      watcher = Actor[pod_watcher_symbol(cluster)]
      watcher.terminate if watcher and watcher.alive?
      start_watcher(cluster)
    end

    private

    def handle_error(notice)
      if notice.type == 'ERROR'
        error notice.object.message
        true
      else
        false
      end
    end

    def handle_notice(notice)
      debug notice.to_s
      return if handle_error(notice) || !notice.object.metadata.labels
      project = notice.object.metadata.labels['project']
      publish(project, notice) if project
    end

    %w{debug info warn error}.each do |level|
      define_method level do |message|
        super "#{name} -> #{message}"
      end
    end
  end
end
