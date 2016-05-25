require 'kubeclient'

class KuberDeployService
  attr_reader :kuber_release

  delegate :build, to: :kuber_release

  def initialize(kuber_release)
    @kuber_release = kuber_release
  end

  def deploy!
    log 'starting deploy'

    start_watching_cluster

    create_services!
    create_deployments!

    log 'API requests complete'
  rescue => ex
    Rails.logger.warn "*********** Couldn't deploy: #{ex.message}"
    raise ex
  end

  def create_deployments!
    kuber_release.release_docs.each do |release_doc|
      log 'creating Deployment', role: release_doc.kubernetes_role.name
      release_doc.deploy
    end
  end

  def create_services!
    kuber_release.release_docs.each do |release_doc|
      status = release_doc.ensure_service
      role = release_doc.kubernetes_role
      log status, role: role.name, service_name: release_doc.kubernetes_role.service_name
    end
  end

  def project
    @project ||= kuber_release.project
  end

  private

  def log(msg, extra_info = {})
    extra_info[:release] = kuber_release.id
    extra_info[:project] = project.name

    Kubernetes::Util.log msg, extra_info
  end

  # Restarts a deploy watcher, forcing it to get in synch with the cluster
  def start_watching_cluster
    Watchers::DeployWatcher.restart_watcher(project)
  end
end
