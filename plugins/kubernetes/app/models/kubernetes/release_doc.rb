module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    include Kubernetes::HasStatus

    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validates :replica_target, presence: true, numericality: { greater_than: 0 }
    validates :replicas_live, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :status, presence: true, inclusion: STATUSES
    validate :validate_config_file, on: :create

    def fail!
      update_attribute(:status, :failed)
    end

    def build
      kubernetes_release.try(:build)
    end

    def update_release
      kubernetes_release.update_status(self)
    end

    def update_status(live_pods)
      case
      when live_pods == replica_target then self.status = :live
      when live_pods.zero? then self.status = :dead
      when live_pods > replicas_live then self.status = :spinning_up
      when live_pods < replicas_live then self.status = :spinning_down
      end
      save!
    end

    def update_replica_count(new_count)
      update_attributes!(replicas_live: new_count)
    end

    def live_replicas_changed?(new_count)
      new_count != replicas_live
    end

    def recovered?(failed_pods)
      failed_pods == 0
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    def deploy_to_kubernetes
      resource = case deploy_yaml.resource_name
      when 'deployment' then Kubeclient::Deployment.new(deploy_yaml.to_hash)
      when 'daemon_set' then Kubeclient::DaemonSet.new(deploy_yaml.to_hash)
      else raise "Unknown resource #{deploy_yaml.resource_name}"
      end

      action = (resource_running?(resource) ? "update" : "create")
      extension_client.send "#{action}_#{deploy_yaml.resource_name}", resource
    end

    def ensure_service
      if service.nil?
        'no Service defined'
      elsif service.running?
        'Service already running'
      else
        data = service_hash
        if data.fetch(:metadata).fetch(:name).include?(Kubernetes::Role::GENERATED)
          raise Samson::Hooks::UserError, "Service name for role #{kubernetes_role.name} was generated and needs to be changed before deploying."
        end
        client.create_service(Kubeclient::Service.new(data))
        'creating Service'
      end
    end

    def raw_template
      @raw_template ||= build.file_from_repo(template_name)
    end

    def template_name
      kubernetes_role.config_file
    end

    private

    # Create new client as 'Deployment' API is on different path then 'v1'
    def extension_client
      deploy_group.kubernetes_cluster.extension_client
    end

    def deploy_yaml
      @deploy_yaml ||= DeployYaml.new(self)
    end

    def resource_running?(resource)
      extension_client.send("get_#{deploy_yaml.resource_name}", resource.metadata.name, resource.metadata.namespace)
    rescue KubeException
      false
    end

    def service
      if kubernetes_role.service_name.present?
        Kubernetes::Service.new(role: kubernetes_role, deploy_group: deploy_group)
      end
    end

    def service_hash
      @service_hash || begin
        hash = service_template

        hash.fetch(:metadata)[:name] = kubernetes_role.service_name
        hash.fetch(:metadata)[:namespace] = namespace

        # For now, create a NodePort for each service, so we can expose any
        # apps running in the Kubernetes cluster to traffic outside the cluster.
        hash.fetch(:spec)[:type] = 'NodePort'

        hash
      end
    end

    # Config has multiple entries like a ReplicationController and a Service
    def service_template
      services = Array.wrap(parsed_config_file).select { |doc| doc['kind'] == 'Service' }
      unless services.size == 1
        raise Samson::Hooks::UserError, "Template #{template_name} has #{services.size} services, having 1 section is valid."
      end
      services.first.with_indifferent_access
    end

    def parsed_config_file
      Kubernetes::Util.parse_file(raw_template, template_name)
    end

    def validate_config_file
      if build && kubernetes_role && raw_template.blank?
        errors.add(:build, "does not contain config file '#{template_name}'")
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
