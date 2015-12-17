require 'celluloid/current'
require 'celluloid/io'

module Watchers
  class BaseClusterWatcher
    include Celluloid::IO
    include Celluloid::Internals::Logger

    finalizer :stop_watching

    def initialize(watch_stream)
      @watch_stream = watch_stream
      async :start_watching
    end

    def start_watching
      info 'watcher started'
      @watch_stream.each do |notice|
        base_handle_notice notice
      end
    end

    def stop_watching
      info 'watcher stopped'
      if @watch_stream
        @watch_stream.finish
        @watch_stream = nil
      end
    end

    def self.watcher_symbol(cluster)
      "#{self.name.demodulize.underscore}_#{cluster.id}".to_sym
    end

    def self.start_watcher(cluster)
      watcher_name = watcher_symbol(cluster)
      supervise as: watcher_name, args: [cluster]
    end

    def self.restart_watcher(cluster)
      watcher = Actor[watcher_symbol(cluster)]
      watcher.terminate if watcher and watcher.alive?
      start_watcher(cluster)
    end

    protected

    def base_handle_notice(notice)
      debug notice.to_s
      handle_notice(notice) unless handle_error(notice)
    end

    def handle_error(notice)
      if notice.type == 'ERROR'
        error notice.object.message
        true
      else
        false
      end
    end

    def handle_notice(_notice)
      fail 'handle_notice not implemented!'
    end

    def message(event, options={})
      base = { event: event }
      OpenStruct.new(base.merge(options))
    end

    %w{debug info warn error}.each do |level|
      define_method level do |message|
        super "#{name} -> #{message}"
      end
    end
  end
end
