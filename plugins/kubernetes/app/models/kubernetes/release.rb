module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    STATUSES = %w[created spinning_up live spinning_down dead]

    belongs_to :user
    belongs_to :build
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id'

    delegate :project, to: :build

    validates :build, presence: true
    validates :status, inclusion: STATUSES
    validate :docker_image_in_registry?, on: :create

    STATUSES.each do |s|
      define_method("#{s}?") { status == s }
    end

    def release_is_live
      self.status = 'live'
      self.deploy_finished_at = Time.now
    end

    def pod_labels
      {
        project: build.project_name,
        release_id: id.to_s
      }
    end

    def user
      super || NullUser.new(user_id)
    end

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

    def docs_by_role
      @docs_by_role ||= release_docs.each_with_object({}) do |rel_doc, hash|
        hash[rel_doc.kubernetes_role.label_name] = rel_doc
      end
    end

    def deploy_group_ids
      release_docs.map(&:deploy_group_id)
    end

    def deploy_group_ids=(id_list)
    end

    private

    def docker_image_in_registry?
      if build && build.docker_repo_digest.blank?
        errors.add(:build, 'Docker image was not pushed to registry')
      end
    end
  end
end
