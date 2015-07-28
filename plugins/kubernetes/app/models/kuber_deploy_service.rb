class KuberDeployService
  attr_reader :kuber_release

  delegate :client, to: Kubernetes
  delegate :build, to: :kuber_release

  def initialize(kuber_release)
    @kuber_release = kuber_release
  end

  def deploy!
    create_replication_controller!
    create_service! unless service_exists?
  end

  def create_replication_controller!
    rc = Kubeclient::ReplicationController.new(kuber_release.rc_hash)
    client.create_replication_controller(rc)
  end

  def create_service!
    service = Kubeclient::Service.new(kuber_release.service_hash)
    client.create_service(service)
  end

  def other_repl_controllers
    @prev_repl_controller ||= begin
      client.get_replication_controllers(label_selector: "project=#{build.project_name},component=app-server").
          select { |rc| rc.metadata.labels.build != kuber_release.build_label }.
          first
    end
  end

  def services
    # TODO: only return services in the same namespace
    client.get_services(label_selector: "name=#{build.service_name}")
  end

  def service_exists?
    services.any?
  end
end
