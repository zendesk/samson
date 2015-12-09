module Watchers
  # Instantiated when a Kubernetes deploy is created to watch the status
  class DeployWatcher
    include Celluloid
    include Celluloid::Notifications
    include Celluloid::Internals::Logger

    finalizer :on_termination

    def initialize(release)
      @release = release
      @current_rcs = {}
      info "Start watching K8s deploy: #{@release}"
      async :watch
    end

    def watch
      @release.release_docs.each do |release_doc|
        subscribe("#{release_doc.replication_controller_name}", :handle_update)
      end
    end

    def handle_update(topic, data)
      release_doc = release_doc_from_rc_name(topic)
      pod_event = Events::PodEvent.new(data)
      return error('invalid k8s pod event') unless pod_event.valid?
      update_replica_count(release_doc, pod_event)
      send_event(role: release_doc.kubernetes_role.name,
                 deploy_group: release_doc.deploy_group.name,
                 target_replicas: release_doc.replica_target,
                 live_replicas: release_doc.replicas_live)
      end_deploy if deploy_finished?
    end

    private

    def deploy_finished?
      @release.release_docs.all?(&:live?)
    end

    def release_doc_from_rc_name(name)
      @release.release_docs.select { |doc| doc.replication_controller_name == name }.first
    end

    def on_termination
      Rails.logger.info('Finished Watching Deploy!')
    end

    def update_replica_count(release_doc, pod_event)
      rc = rc_pods(release_doc.replication_controller_name)

      if pod_event.deleted?
        rc.delete(pod_event.pod.name)
      else
        rc[pod_event.pod.name] = pod_event.pod
      end

      ready_count = rc.reduce(0) { |count, (_pod_name, pod)| count += 1 if pod.ready?; count }
      release_doc.update_replica_count(ready_count) unless release_doc.replicas_live == ready_count
      @release.update_columns(status: :spinning_up) if @release.created?
    end

    def end_deploy
      @release.release_is_live!
      Rails.logger.info('Deploy is live!')
      terminate
    end

    def rc_pods(name)
      @current_rcs[name] ||= {}
      @current_rcs[name]
    end

    def send_event(options)
      base = {
        project: @release.project.id,
        build: @release.build.label,
        release: @release.id
      }

      Rails.logger.info("[SSE] Sending: #{base.merge(options)}")

      SseRailsEngine.send_event('k8s', base.merge(options))
    end
  end
end
