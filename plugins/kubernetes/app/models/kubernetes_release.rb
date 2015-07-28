class KubernetesRelease < ActiveRecord::Base
  belongs_to :user
  belongs_to :build
  belongs_to :deploy_group

  validates :replicas, numericality: { greater_than: 0 }

  before_create :serialize_rc_doc!, :set_default_status

  def namespace
    deploy_group.namespace
  end

  def build_label
    "#{build.project_name}-build-#{build.id}"
  end

  def rc_hash
    @rc_has ||= {
      metadata: {
        name: build.controller_name,
        namespace: namespace,
        labels: rc_labels
      },
      spec: {
        replicas: replicas,
        selector: rc_selector,
        template: pod_template
      }
    }
  end

  def service_hash
    @service_hash ||= {
      metadata: {
        name: build.service_name,
        namespace: namespace,
        labels: service_labels
      },
      spec: {
        selector: {
          app: build.pod_name,
          component: 'app-server'
        },
        ports: [
          {
            port: build.service_port,
            targetPort: build.container_port
          }
        ],
      }
    }
  end

  def rc_labels
    {
      project: build.project_name,
      component: 'app-server',
      build: build_label
    }
  end

  def rc_selector
    {
      app: build.pod_name,
      build: build_label,
      component: 'app-server'
    }
  end

  def pod_labels
    {
      app: build.pod_name,
      project: build.project_name,
      build: build_label,
      component: 'app-server'
    }
  end

  def service_labels
    {
      name: build.service_name,
      project: build.project_name,
      component: 'app-server'
    }
  end

  def serialize_rc_doc!
    self.replication_controller_doc = rc_hash.to_json
  end

  def pretty_rc_doc(format: :json)
    hash = JSON.parse(replication_controller_doc)

    case format
      when :json
        JSON.pretty_generate(hash)
      when :yaml, :yml
        hash.to_yaml
      else
        hash.to_s
    end
  end

  # TODO: remove this hack
  def deploy_group_ids
    [deploy_group_id]
  end

  private

  def pod_template
    hash = {
      metadata: {
        name: build.pod_name,
        namespace: namespace,
        labels: pod_labels
      },
      spec: {
        containers: [project_container],
        volumes: volumes,
        restartPolicy: 'Always',
        dnsPolicy: 'Default'
      }
    }

    command = role_definition[:command]
    case command
      when Array
        hash[:command] = command
      when String
        hash[:command] = command.split(' ')
      else
        # no-op
    end

    hash
  end

  def project_container
    {
      name: build.pod_name,
      image: build.docker_repo_digest,
      imagePullPolicy: 'Always',
      ports: ports,
      env: env_as_list,
      volumeMounts: volume_mounts
    }
  end

  def env_as_list
    build.env_for(deploy_group).each_with_object([]) do |(k,v), list|
      list << { name: k, value: v.to_s }
    end
  end

  def ports
    port_list = []
    port_list << { containerPort: build.container_port, protocol: 'TCP' }
    port_list
  end

  def volumes
    []
  end

  def volume_mounts
    # TODO: will need to use this if we mount secrets
    []
  end

  def role_definition
    @role_definitions ||= build.manifest_roles.fetch(self.role, {})
  end

  def set_default_status
    self.status ||= 'created'
  end
end
