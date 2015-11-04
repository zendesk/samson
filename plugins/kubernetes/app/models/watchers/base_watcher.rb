module Watchers
  # An abstract class for watching activity on one or more Kubernetes
  # objects via their API.  Expects an instance of Kubeclient::Common::WatchStream
  # to be passed in.
  class BaseWatcher
    attr_reader :start_time

    def initialize(watch_stream, log: true)
      @watch_stream, @log, = watch_stream, log
      @start_time = Time.now
      @enabled = false
    end

    def start_watching(&block)
      @enabled = true
      @watch_stream.each do |notice|
        handle_notice(notice, &block)
        break if stop_watching?
      end
      cleanup
    end

    def stop_watching
      @enabled = false
    end

    def time_watching
      Time.now - start_time
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

    def stop_watching?
      not @enabled
    end

    def cleanup
      if @watch_stream
        @watch_stream.finish
        @watch_stream = nil
      end
    end
  end
end
