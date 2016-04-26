module Watchers
  class DeployWatcher
    include Celluloid
    include Celluloid::Notifications
    include Celluloid::Internals::Logger

    finalizer :on_termination

    class << self
      def restart_watcher(project)
        stop_watcher(project)
        start_watcher(project)
      end

      private

      def stop_watcher(project)
        watcher = Celluloid::Actor[watcher_symbol(project)]
        watcher.terminate if watcher && watcher.alive?
      end

      def watcher_symbol(project)
        "deploy-watcher-#{project.id}".to_sym
      end

      def start_watcher(project)
        watcher_name = watcher_symbol(project)
        supervise as: watcher_name, args: [project]
      end
    end

    private

    def initialize(project)
      @project = project
      @pod_timer = after(ENV.fetch('KUBERNETES_POD_TIMEOUT', 20.minutes).to_i) { pod_timeout }
      start_watching
    end

    def start_watching
      sync_with_cluster
      info "Start watching deployment for project: #{@project.name}"
      async :watch
    end

    def watch
      subscribe(Watchers::TopicSubscription.pod_updates_topic(@project.id), :handle_event)
    end

    def handle_event(topic, message)
      event = message.event
      debug "Got message on topic: #{topic}. Type of message: #{event.kind}"

      case
      when event.kind == 'Event' then handle_cluster_event(message)
      when event.kind == 'Pod' then handle_pod_event(message)
      else error "Object kind not yet supported: #{event.kind}"
      end
    end

    # Gets the database in-sync with the Kubernetes Cluster
    def sync_with_cluster
      fetch_cluster_data
      reconcile_old_releases
      reconcile_db_with_cluster
    end

    # From the target environment for the current Release, fetches all existing Pods from the corresponding
    # Kubernetes Clusters and updates the internal data structures used by the watcher.
    def fetch_cluster_data
      env = release_env(last_release(@project))
      env.cluster_deploy_groups.each do |cdg|
        cdg.cluster.client.get_pods(namespace: cdg.namespace, label_selector: "project_id=#{@project.id}").each do |pod|
          update_rc_pods(Kubernetes::Api::Pod.new(pod))
        end
      end
    end

    def release_env(release)
      release.deploy_groups.first.environment
    end

    # Will mark as :dead each previous Release for which there is no Pod in the cluster.
    # Will mark as :dead each ReleaseDoc belonging to a previous Release for which there is no Pod in the cluster.
    def reconcile_old_releases
      excluded_from_sync = release_ids_from_cluster << last_release(@project).id

      scope = @project.kubernetes_releases.excluding(excluded_from_sync)

      scope.not_dead.update_all(status: :dead)
      scope.with_not_dead_release_docs.distinct.each { |rel| rel.release_docs.update_all(status: :dead) }
    end

    # Get previous releases in sync with the cluster (when there's at least a Pod in the cluster)
    def reconcile_db_with_cluster
      rcs.each_value { |pods| pods.each_value { |pod| handle_pod_update(pod) } }
    end

    def handle_cluster_event(message)
      pod = message.pod
      existing_pod = rc_pod(pod)

      unless existing_pod && existing_pod.live?
        # If the Pod already exists internally, update it only if it's not live already. The Failed/FailedScheduling
        # events may take longer to arrive than the actual Pod update, which will incorrectly update the ReleaseDoc to
        # failed if the Pod is actually live (seen during development)
        pod.extend(Kubernetes::Api::FailedPod)
        update_rc_pods(pod)

        release = Kubernetes::Release.find(pod.release_id)
        release_doc = release.release_doc_for(pod.deploy_group_id, pod.role_id)
        release_doc.fail! unless release_doc.failed?

        failed_pods = count_failed_pods(pod.rc_unique_identifier)
        send_event(release_doc, failed_pods)
      end
    end

    def handle_pod_event(message)
      pod_event = message.event
      pod = message.event.pod
      pod.extend(Kubernetes::Api::DeletedPod) if pod_event.deleted?

      handle_pod_update(pod) do |release_doc, failed_pods|
        send_event(release_doc, failed_pods)
        terminate_watcher if deploy_finished?(@project)
      end
    end

    def handle_pod_update(pod)
      update_rc_pods(pod)
      release = Kubernetes::Release.find(pod.release_id)
      release_doc = release.release_doc_for(pod.deploy_group_id, pod.role_id)

      live_pods = count_live_pods(pod.rc_unique_identifier)
      failed_pods = count_failed_pods(pod.rc_unique_identifier)

      if not_recovered?(release_doc, failed_pods)
        update_failed_release_doc(release_doc, live_pods)
        yield release_doc, failed_pods if block_given?
      else
        update_release_doc(release_doc, live_pods) do
          yield release_doc, failed_pods if block_given?
        end
      end
    end

    def not_recovered?(release_doc, failed_pods)
      release_doc.failed? && !release_doc.recovered?(failed_pods)
    end

    def update_release_doc(release_doc, live_pods)
      reset_timeout

      if release_doc.live_replicas_changed?(live_pods)
        release_doc.update_status(live_pods)
        release_doc.update_replica_count(live_pods)
        release_doc.update_release
        yield
      end
    end

    def update_failed_release_doc(release_doc, live_pods)
      if release_doc.live_replicas_changed?(live_pods)
        release_doc.update_replica_count(live_pods)
      end
    end

    # Involved object identifies the Kubernetes resource that triggered the event
    def involved_object_for(notice)
      notice.object.involvedObject
    end

    def cluster_for(cluster_id)
      Kubernetes::Cluster.find(cluster_id)
    end

    def rcs
      @rcs ||= {}
    end

    def rc_pods(rc_unique_id)
      rcs[rc_unique_id] ||= {}
      rcs[rc_unique_id]
    end

    def update_rc_pods(pod)
      rc = rc_pods(pod.rc_unique_identifier)
      rc[pod.name] = pod
    end

    def rc_pod(pod)
      rc = rc_pods(pod.rc_unique_identifier)
      rc[pod.name]
    end

    def release_ids_from_cluster
      rcs.map { |_, pods| pods.map { |_, pod| pod.release_id } }.flatten.uniq
    end

    def last_release(project)
      project.kubernetes_releases.last
    end

    def count_live_pods(rc_unique_identifier)
      rc = rc_pods(rc_unique_identifier)
      rc.reduce(0) { |count, (_, pod)| count += 1 if pod.live?; count }
    end

    def count_failed_pods(rc_unique_identifier)
      rc = rc_pods(rc_unique_identifier)
      rc.reduce(0) { |count, (_, pod)| count += 1 if failed?(pod); count }
    end

    def failed?(pod)
      pod.respond_to?(:failed?) && pod.failed?
    end

    def reset_timeout
      @pod_timer.reset
    end

    def pod_timeout
      last_release(@project).fail!
      warn 'Deploy failed!'
      terminate
    end

    def deploy_finished?(project)
      last_release(project).live? && project.kubernetes_releases.excluding(last_release(project).id).all?(&:dead?)
    end

    def on_termination
      @pod_timer.cancel
      info('Finished Watching Deployments!')
    end

    def terminate_watcher
      info('Deploy finished!')
      terminate
    end

    def send_event(release_doc, failed_pods)
      debug("[SSE] Sending: #{sse_event_data(release_doc, failed_pods)}")
      SseRailsEngine.send_event('k8s', sse_event_data(release_doc, failed_pods))
    end

    def sse_event_data(release_doc, failed_pods)
      {
        project: release_doc.kubernetes_release.project.id,
        role: {
          id: release_doc.kubernetes_role.id,
          name: release_doc.kubernetes_role.name
        },
        deploy_group: {
          id: release_doc.deploy_group.id,
          name: release_doc.deploy_group.name
        },
        release: {
          id: release_doc.kubernetes_release.id,
          build: release_doc.kubernetes_release.build.label,
          target_replicas: release_doc.replica_target,
          live_replicas: release_doc.replicas_live,
          failed: release_doc.failed?,
          failed_pods: failed_pods
        }
      }
    end
  end
end
