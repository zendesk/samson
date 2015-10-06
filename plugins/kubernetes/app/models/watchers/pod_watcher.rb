module Watchers
  class PodWatcher < BaseWatcher
    POD_PHASES = %w[Pending Running Succeeded Failed Unknown]
    
    attr_reader :pod_info

    def initialize(client, namespace, name: nil, label_selector: nil, log: true)
      raise ArgumentError.new('Must specify either pod_name or label_selector') if name.blank? && label_selector.blank?
      watcher = client.watch_pods(name: name, namespace: namespace, label_selector: label_selector)
      super(watcher, log: log)

      @pod_info = {}
    end

    def pod_names
      @pod_info.keys
    end

    # Returns a hash with the number of pods in each status
    def status_counts
      counts = {}
      POD_PHASES.each { |phase| counts[phase] = 0  }
      @pod_info.each do |pod_name, notice|
        counts[notice.phase] += 1
      end
      counts
    end

    def num_ready
      @pod_info.values.count(&:ready?)
    end

    protected

    # Notes on how to tell whether a deploy is successful or not:
    #
    # Keep track of the Pods that are created
    # Watch for them to be all running and ready
    # Once we have a set of all pod names, subscribe to events related to them
    #   e.g. client.watch_events(fieldSelector: "involvedObject.name IN (pod1,pod2,...)")
    #   look for any Events that look like a failure (e.g. failedScheduling)
    # When all the pods are ready and running, mark the deploy as successful

    def handle_notice(notice, &block)
      return if handle_error(notice)
      notice.extend(PWrapper)
      yield(notice, self) if block_given?

      # keep track of the state of all pods
      @pod_info[notice.pod_name] = notice

      log "Received Pod notice", watcher: 'pod', notice_type: notice.type, phase: notice.phase, ready: notice.ready?, status_counts: status_counts
    end

    # Decorator class for the Pod data that is returned
    # see https://htmlpreview.github.io/?https://github.com/kubernetes/kubernetes/HEAD/docs/api-reference/definitions.html#_v1_pod
    module PWrapper
      def pod_name
        object.metadata.name
      end

      def role
        object.metadata.labels.role
      end

      def phase
        object.status.phase
      end

      def started_at
        Time.parse(object.status.startTime)
      end

      def running?
        phase == 'Running'
      end

      def ready?
        object.status.conditions.present? &&
          object.status.conditions.select { |c| c['type'] == 'Ready' }.all? { |c| c['status'] == 'True' }
      end
    end
  end
end
