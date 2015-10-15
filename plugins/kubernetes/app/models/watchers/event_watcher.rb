module Watchers
  class EventWatcher < BaseWatcher
    attr_reader :event_info, :object_names

    def initialize(client, namespace, object_kind: nil, object_names: [], log: true)
      field_selectors = []
      field_selectors << "involvedObject.kind=#{object_kind}" if object_kind.present?

      if object_names.count == 1
        field_selectors << "involvedObject.name=#{object_name.first}"
        @object_names = []
      else
        @object_names = object_names
      end

      log 'Starting Pod event watch', pod_names: @object_names, field_selector: field_selectors.join(',')

      watcher = client.watch_events(namespace: namespace, field_selector: field_selectors.join(','))
      super(watcher, log: log)

      @event_info = {}
    end

    protected

    def handle_notice(notice, &block)
      return if handle_error(notice)
      notice.extend(EventWrapper)

      if @object_names.any? && !@object_names.include?(notice.object_name)
        # log 'Ignoring event', object_name: notice.object_name, kind: notice.object_kind
        return
      end

      log 'Event received', watcher: 'event', notice_type: notice.type, object: notice.object_name, event_message: notice.message, reason: notice.reason

      yield(notice, self) if block_given?

      # keep track of the state of all pods
      @event_info[notice.object_name] = notice
    end

    # Decorator class for the Pod data that is returned
    # see https://htmlpreview.github.io/?https://github.com/kubernetes/kubernetes/HEAD/docs/api-reference/definitions.html#_v1_pod
    module EventWrapper
      def object_name
        object.involvedObject.name
      end

      def object_kind
        object.involvedObject.kind
      end

      def object_uid
        object.involvedObject.uid
      end

      def object_version
        object.involvedObject.resourceVersion.to_i
      end

      def message
        object.message
      end

      def reason
        object.reason
      end
    end
  end
end
