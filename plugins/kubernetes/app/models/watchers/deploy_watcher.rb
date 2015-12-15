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
      @pod_timer = after(ENV.fetch('KUBERNETES_POD_TIMEOUT', 10.minutes).to_i) { pod_timeout }
      info "Start watching K8s deploy: #{@release}"
      async :watch
    end

    def watch
      subscribe("#{@release.build.project_name}", :handle_update)
    end

    def handle_update(topic, data)
      info "Got Release Event: #{topic}"
      release_doc = release_doc_from_rc_name(topic)
      release_updated = if data.object.kind == 'Event'
                        handle_event_update(release_doc)
                      else
                        handle_pod_update(release_doc, data)
                      end
      if release_updated
        send_event(role: release_doc.kubernetes_role.name,
                   deploy_group: release_doc.deploy_group.name,
                   target_replicas: release_doc.replica_target,
                   live_replicas: release_doc.replicas_live,
                   failed: release_doc.failed?)
        end_deploy if deploy_finished?
      end
    end

    private

    def handle_event_update(release_doc)
      release_doc.failed? ? false : release_doc.fail!
    end

    def handle_pod_update(release_doc, data)
      pod_event = Events::PodEvent.new(data)
      if pod_event.valid?
        update_replica_count(release_doc, pod_event)
        update_timeout(pod_event)
        true
      else
        error 'invalid k8s pod event'
        false
      end
    end

    def deploy_finished?
      @release.release_docs.all?(&:live?)
    end

    def release_doc_from_rc_name(name)
      @release.release_docs.select { |doc| doc.replication_controller_name == name }.first
    end

    def on_termination
      info 'Finished Watching Deploy!'
      @pod_timer.cancel
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

    def update_timeout(pod_event)
      unless pod_event.deleted?
        @pod_timer.reset if pod_event.pod.ready?
      end
    end

    def end_deploy
      @release.release_is_live!
      info 'Deploy is live!'
      terminate
    end

    def pod_timeout
      @release.release_failed!
      warn 'Deploy failed!'
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
