module Watchers
  # An abstract class for watching activity on one or more Kubernetes
  # objects via their API.  Expects an instance of Kubeclient::Common::WatchStream
  # to be passed in.
  class BaseWatcher
    def initialize(watch_stream, log: true)
      @watch_stream, @log, = watch_stream, log
    end

    def start_watching(&block)
      @watch_stream.each do |notice|
        handle_notice(notice, &block)
      end
    end

    def stop_watching
      if @watch_stream
        @watch_stream.finish
        @watch_stream = nil
      end
    end

    protected

    def handle_notice(notice, &block)
      # Kubernetes::Util.log notice.to_json
      yield notice if block_given?
    end

    def handle_error(notice)
      if notice.type == 'ERROR'
        log "ERROR: #{notice.object.message}"
        true
      else
        false
      end
    end

    def log(msg, extra_info = {})
      Kubernetes::Util.log(msg, extra_info) if @log
    end
  end
end
