require 'kubeclient'

class KuberDeployService
  attr_reader :kuber_release

  delegate :build, to: :kuber_release

  def initialize(kuber_release)
    @kuber_release = kuber_release
  end

  def deploy!
    # TODO: handling different deploy strategies (rolling updates, etc.)
    Rails.logger.info "Deploying Kubernetes::Release #{kuber_release.id}, project '#{project.name}' to DeployGroup #{kuber_release.deploy_group.name}"

    create_replication_controllers!
    create_services!

    Rails.logger.info "Deploying complete for Kubernetes::Release #{kuber_release.id}, project '#{project.name}' to DeployGroup #{kuber_release.deploy_group.name}"
  end

  def create_replication_controllers!
    kuber_release.release_docs.each do |release_doc|
      Rails.logger.info "Creating ReplicationController for Kubernetes::Release #{kuber_release.id}, role: #{release_doc.kubernetes_role.name}"

      rc = Kubeclient::ReplicationController.new(release_doc.rc_hash)
      client.create_replication_controller(rc)
    end
  end

  def create_services!
    # TODO: implement this
  end

  def project
    @project ||= kuber_release.release_group.project
  end

  private

  def client
    kuber_release.deploy_group.kubernetes_cluster.client
  end
end
