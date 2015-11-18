require 'celluloid/current'
require 'celluloid/io'

module Watchers
  class ClusterPodWatcher
    include Celluloid::IO
    include Celluloid::Notifications
    include Celluloid::Internals::Logger

    finalizer :stop_watching

    def initialize(client)
      @started = false
      @client = client
      @watch_stream = nil
      async :start_watching
    end

    def start_watching
      info 'watcher started'
      @started = true
      @watch_stream = @client.watch_pods
      @watch_stream.each do |notice|
        handle_notice notice
      end
    end

    def stop_watching
      info 'watcher stopped'
      @started = false
      if @watch_stream
        @watch_stream.finish
        @watch_stream = nil
      end
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
      return if handle_error(notice)
      rc_name = notice.object.metadata.labels['replication_controller']
      publish rc_name, notice if rc_name
    end

    %w{debug info warn error}.each do |level|
      define_method level do |message|
        super "#{name} -> #{message}"
      end
    end
  end
end
