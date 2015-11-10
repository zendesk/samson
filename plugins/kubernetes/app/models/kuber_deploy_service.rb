require 'kubeclient'

class KuberDeployService
  attr_reader :kuber_release

  delegate :build, to: :kuber_release

  def initialize(kuber_release)
    @kuber_release = kuber_release
  end

  def deploy!
    # TODO: handling different deploy strategies (rolling updates, etc.)
    log 'starting deploy'

    create_services!
    create_replication_controllers!

    # watch_deployment

    log 'API requests complete'
  end

  def create_replication_controllers!
    kuber_release.release_docs.each do |release_doc|
      log 'creating ReplicationController', role: release_doc.kubernetes_role.name

      rc = Kubeclient::ReplicationController.new(release_doc.rc_hash)
      release_doc.client.create_replication_controller(rc)
    end
  end

  def create_services!
    kuber_release.release_docs.each do |release_doc|
      role = release_doc.kubernetes_role
      service = release_doc.service

      if service.nil?
        log 'no Service defined', role: role.name
      elsif service.running?
        log 'Service already running', role: role.name, service_name: service.name
      else
        log 'creating Service', role: role.name, service_name: service.name
        release_doc.client.create_service(Kubeclient::Service.new(release_doc.service_hash))
      end
    end
  end

  def project
    @project ||= kuber_release.project
  end

  def watch_deployment
    # Doing this for now to force the loading of these constants.
    # I was getting a circular dependency error otherwise
    # TODO: hunt down this issue and fix it properly
    Watchers::PodWatcher ; Watchers::ReplicationControllerWatcher ; Watchers::EventWatcher

    Thread.new do
      kuber_release.watch_pods(&method(:handle_pod_notice))
    end

    # Thread.new { sleep(5) ; kuber_release.watch_pod_events }
  end

  private

  def handle_pod_notice(notice, watcher)
    release_doc = kuber_release.docs_by_role[notice.role]

    if release_doc.nil?
      Kubernetes::Util.log "ERROR: could not find role", role: notice.role, available_roles: kuber_release.docs_by_role.keys
      return
    end

    ready_count = watcher.num_ready
    if ready_count > release_doc.replicas_live
      release_doc.update_replica_count(ready_count)
      release_doc.save!
      update_release_status
      log 'Another replica is live', role: notice.role, count: ready_count, r_status: kuber_release.status, r_doc_status: release_doc.status
    end
  end

  def update_release_status
    if kuber_release.release_docs.all?(&:live?)
      deploy_is_live
    elsif kuber_release.release_docs.any?(&:spinning_up?)
      kuber_release.update_attribute(:status, 'spinning_up') unless kuber_release.spinning_up?
    end
  end

  def deploy_is_live
    kuber_release.release_is_live
    kuber_release.save!

    kuber_release.stop_watching   # this should kill the #watch_pods Thread spawned above
  end

  def log(msg, extra_info = {})
    extra_info.merge!(
      release: kuber_release.id,
      project: project.name
    )

    Kubernetes::Util.log msg, extra_info
  end
end
