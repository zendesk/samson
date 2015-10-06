module Watchers
  class ReplicationControllerWatcher < BaseWatcher
    attr_reader :rc_info

    def initialize(client, namespace, name: nil, label_selector: nil, log: true)
      raise ArgumentError.new('Must specify either pod_name or label_selector') if name.blank? && label_selector.blank?
      watcher = client.watch_replication_controllers(name: name, namespace: namespace, label_selector: label_selector)
      super(watcher, log: log)

      @rc_info = {}
    end

    protected

    def handle_notice(notice, &block)
      return if handle_error(notice)

      notice.extend(RCWrapper)
      yield(notice, self) if block_given?

      log "RC notice received", watcher: 'rc', notice_type: notice.type, rc_name: notice.rc_name, replicas: notice.replica_count

      # keep track of the state of all pods
      @rc_info[notice.rc_name] = notice
    end

    # Decorator class for the Replication Controller data that is returned
    # see https://htmlpreview.github.io/?https://github.com/kubernetes/kubernetes/HEAD/docs/api-reference/definitions.html#_v1_replicationcontroller
    module RCWrapper
      def rc_name
        object.metadata.name
      end

      def role
        object.metadata.labels.role
      end

      def replica_count
        object.status.replicas
      end
    end
  end
end
