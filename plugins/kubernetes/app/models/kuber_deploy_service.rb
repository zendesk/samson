class KuberDeployService
  attr_reader :kuber_release

  delegate :build, to: :kuber_release

  def initialize(kuber_release)
    @kuber_release = kuber_release
  end

  def deploy!
    # TODO: handling different deploy strategies (rolling updates, etc.)
    create_replication_controllers!
    create_services!
  end

  def create_replication_controllers!
    kuber_release.role_releases.each do |krr|
      rc = Kubeclient::ReplicationController.new(krr.rc_hash)
      client.create_replication_controller(rc)
    end
  end

  def create_services!
    # TODO: implement this
  end

  private

  def client
    # TODO: get the correct client based on the release's DeployGroup
    @client ||= Kubernetes.client
  end
end
