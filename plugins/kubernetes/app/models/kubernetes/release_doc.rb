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

    def has_service?
      kubernetes_role.has_service? && service_template.present?
    end

    def service_hash
      @service_hash || (build_service_hash if has_service?)
    end

    def service
      kubernetes_role.service_for(deploy_group) if has_service?
    end

    def build
      kubernetes_release.try(:build)
    end

    def nested_error_messages
      errors.full_messages
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
        client.create_service(Kubeclient::Service.new(service_hash))
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

    def service_template
      # It's possible for the file to contain more than one definition,
      # like a ReplicationController and a Service.
      # TODO: validate there are not multiple services
      @service_template ||= begin
        hash = Array.wrap(parsed_config_file).detect { |doc| doc['kind'] == 'Service' }
        (hash || {}).freeze
      end
    end

    def build_service_hash
      @service_hash = service_template.dup.with_indifferent_access

      @service_hash[:metadata][:name] = kubernetes_role.service_name
      @service_hash[:metadata][:namespace] = namespace
      @service_hash[:metadata][:labels] ||= labels.except(:release_id)

      # For now, create a NodePort for each service, so we can expose any
      # apps running in the Kubernetes cluster to traffic outside the cluster.
      @service_hash[:spec][:type] = 'NodePort'

      @service_hash
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
