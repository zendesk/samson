module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    VALID_STATUSES = %w[created spinning_up live spinning_down dead]

    belongs_to :release_group, class_name: 'Kubernetes::ReleaseGroup', foreign_key: 'kubernetes_release_group_id', inverse_of: :releases
    belongs_to :deploy_group
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id', inverse_of: :kubernetes_release

    validates :release_group, presence: true
    validates :deploy_group, presence: true
    validates :status, inclusion: VALID_STATUSES

    after_initialize :set_default_status, on: :create

    def namespace
      deploy_group.kubernetes_namespace
    end

    def pod_labels
      {
        project: release_group.build.project_name,
        release_id: id.to_s
      }
    end

    # TODO: define state machine for 'status' field

    def nested_error_messages
      errors.full_messages + release_docs.flat_map(&:nested_error_messages)
    end

    def watch_pods(&block)
      @pod_watcher = Watchers::PodWatcher.new(client, namespace,
                                              label_selector: pod_labels.to_kuber_selector,
                                              log: true)
      @pod_watcher.start_watching(&block)
    end

    def watch_rcs(&block)
      @rc_watcher = Watchers::ReplicationControllerWatcher.new(client, namespace,
                                                               label_selector: pod_labels.to_kuber_selector,
                                                               log: true)

      @rc_watcher.start_watching(&block)
    end

    def watch_pod_events(&block)
      pod_names = @pod_watcher.try(:pod_names).presence || find_pod_names

      if pod_names.empty?
        Kubernetes::Util.log 'No pods to watch', release_id: id
        return
      end

      @event_watcher = Watchers::EventWatcher.new(client, namespace,
                                                  object_kind: 'Pod',
                                                  object_names: pod_names,
                                                  log: true)
      @event_watcher.start_watching(&block)
    end

    def find_pod_names
      if @pod_watcher
        @pod_watcher.pod_names
      else
        pods = client.get_pods(namespace: namespace, label_selector: pod_labels.to_kuber_selector)
        pods.map { |p| p.metadata.name }
      end
    end

    def stop_watching
      [@pod_watcher, @rc_watcher].each do |watcher|
        watcher.stop_watching if watcher
      end
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    private

    def set_default_status
      self.status ||= 'created'
    end
  end
end
