require 'kubeclient'

class KuberDeployService
  attr_reader :kuber_release

  delegate :build, :client, to: :kuber_release

  def initialize(kuber_release)
    @kuber_release = kuber_release
  end

  def deploy!
    # TODO: handling different deploy strategies (rolling updates, etc.)
    log 'starting deploy'

    create_services!
    create_replication_controllers!

    watch_deployment

    log 'API requests complete'
  end

  def create_replication_controllers!
    kuber_release.release_docs.each do |release_doc|
      log 'creating ReplicationController', role: release_doc.kubernetes_role.name

      rc = Kubeclient::ReplicationController.new(release_doc.rc_hash)
      client.create_replication_controller(rc)
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
        client.create_service(Kubeclient::Service.new(release_doc.service_hash))
      end
    end
  end

  def project
    @project ||= kuber_release.release_group.project
  end

  def watch_deployment
    # Doing this for now to force the loading of these constants.
    # I was getting a circular dependency error otherwise
    # TODO: hunt down this issue and fix it properly
    Watchers::PodWatcher ; Watchers::ReplicationControllerWatcher ; Watchers::EventWatcher

    # Commented out for now, to avoid creating threads without ever destroying them
    # Thread.new { kuber_release.watch_pods }
    # Thread.new { kuber_release.watch_rcs }
    # Thread.new { sleep(5) ; kuber_release.watch_pod_events }
  end

  private

  def log(msg, extra_info = {})
    extra_info.merge!(
      release: kuber_release.id,
      project: project.name,
      group: kuber_release.deploy_group.name
    )

    Kubernetes::Util.log msg, extra_info
  end
end
