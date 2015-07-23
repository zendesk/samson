class KuberDeployService
  attr_reader :build, :user, :app_name, :namespace, :port, :env

  delegate :client, to: Kubernetes

  def initialize(build, user, app_name: nil, namespace: 'default', port: 4242, env: {})
    @build, @user, @namespace, @port, @env = build, user, namespace, port, env

    @app_name = app_name || @build.project.name.parameterize('-')
    @env = {} unless @env.is_a? Hash
  end

  def create_replication_controller(replicas: 1)
    client.create_replication_controller(replication_controller(replicas: replicas))
  end

  def create_service
    client.create_service(service)
  end

  def service_exists?
    client.get_services(label_selector: "name=#{app_name}-frontend").count > 0
  end

  def replication_controller(replicas: 1)
    @rc ||= Kubeclient::ReplicationController.new({
      metadata: {
        name: "#{app_name}-controller",
        namespace: namespace,
        labels: {
          project: app_name,
          component: 'app-server'
        }
      },
      spec: {
        replicas: replicas,
        selector: {
          app: app_name
        },
        template: pod_template
      }
    })
  end

  def service
    @service ||= Kubeclient::Service.new({
      metadata: {
        name: "#{app_name}-frontend",
        namespace: namespace,
        labels: {
          name: "#{app_name}-frontend",
          project: app_name,
          component: 'app-server'
        }
      },
      spec: {
        ports: [
          {
            port: 80,
            targetPort: port
          }
        ],
      }
    })
  end

  private

  def pod_template
    {
      metadata: {
        name: app_name,
        namespace: namespace,
        labels: {
          app: app_name,
          project: app_name,
          component: 'app-server'
        }
      },
      spec: {
        containers: [project_container]
      }
    }
  end

  def project_container
    {
      name: app_name,
      image: build.docker_repo_digest,
      ports: [
        {
          containerPort: port
        }
      ],
      env: env_as_list
    }
  end

  def env_as_list
    env.each_with_object([]) do |(k,v), list|
      list << { name: k, value: v.to_s }
    end
  end
end
