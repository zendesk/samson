class KuberDeployService
  attr_reader :build, :user, :app_name, :namespace, :port, :env

  delegate :client, to: Kubernetes

  def initialize(build, user, namespace: 'default', env: {})
    @build, @user, @namespace, @env = build, user, namespace, env

    @env = {} unless @env.is_a? Hash
  end

  def create_replication_controller(replicas: 1)
    client.create_replication_controller(replication_controller(replicas: replicas))
  end

  def create_service
    client.create_service(service)
  end

  def service_exists?
    client.get_services(label_selector: "name=#{build.service_name}").count > 0
  end

  def replication_controller(replicas: 1)
    @rc ||= Kubeclient::ReplicationController.new({
      metadata: {
        name: build.controller_name,
        namespace: namespace,
        labels: {
          project: build.project_name,
          component: 'app-server'
        }
      },
      spec: {
        replicas: replicas,
        selector: {
          release: build.version_label
        },
        template: pod_template
      }
    })
  end

  def service
    @service ||= Kubeclient::Service.new({
      metadata: {
        name: build.service_name,
        namespace: namespace,
        labels: {
          name: build.service_name,
          project: build.project_name,
          component: 'app-server'
        }
      },
      spec: {
        ports: [
          {
            port: build.service_port,
            targetPort: build.container_port
          }
        ],
      }
    })
  end

  private

  def pod_template(namespace: 'default')
    {
      metadata: {
        name: build.pod_name,
        namespace: namespace,
        labels: {
          app: build.pod_name,
          project: build.project_name,
          release: build.release_label,
          component: 'app-server'
        }
      },
      spec: {
        containers: [project_container],
        volumes: volumes,
        restartPolicy: 'Always',
        dnsPolicy: 'Always'
      }
    }
  end

  def project_container
    {
      name: build.pod_name,
      image: build.docker_repo_digest,
      imagePullPolicy: 'Always',
      ports: [
        {
          containerPort: build.container_port,
          protocol: 'TCP'
        }
      ],
      env: env_as_list,
      volumeMounts: volume_mounts
    }
  end

  def env_as_list
    env.each_with_object([]) do |(k,v), list|
      list << { name: k, value: v.to_s }
    end
  end

  def volumes
    []
  end

  def volume_mounts
    # TODO: will need to use this if we mount secrets
    []
  end
end
