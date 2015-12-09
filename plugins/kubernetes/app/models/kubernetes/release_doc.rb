module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    include Kubernetes::DeployYaml

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validates :replica_target, presence: true, numericality: { greater_than: 0 }
    validates :replicas_live, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :status, presence: true, inclusion: Kubernetes::Release::STATUSES
    validate :validate_config_file, on: :create

    Kubernetes::Release::STATUSES.each do |s|
      define_method("#{s}?") { status == s }
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

    def pretty_rc_doc(format: :json)
      case format
        when :json
          JSON.pretty_generate(deployment_hash)
        when :yaml, :yml
          deployment_hash.to_yaml
        else
          deployment_hash.to_s
      end
    end

    def build
      kubernetes_release.try(:build)
    end

    def nested_error_messages
      errors.full_messages
    end

    def update_replica_count(new_count)
      self.replicas_live = new_count

      if replicas_live >= replica_target
        self.status ='live'
      elsif replicas_live > 0
        self.status ='spinning_up'
      end
    end

    def client
      deploy_group.kubernetes_cluster.client
    end

    def deploy_to_kubernetes
      deployment = Kubeclient::Deployment.new(deployment_hash)
      # Create new client as 'Deployment' API is on different path then 'v1'
      ext_client = deploy_group.kubernetes_cluster.ext_client
      if previous_deploy?(ext_client, deployment)
        ext_client.update_deployment(deployment)
      else
        ext_client.create_deployment(deployment)
      end
    end

    private

    def previous_deploy?(ext_client, deployment)
      ext_client.get_deployment(deployment.metadata.name, deployment.metadata.namespace)
    rescue KubeException
      false
    end

    def service_template
      @service_template ||= begin
                              # It's possible for the file to contain more than one definition,
                              # like a ReplicationController and a Service.
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
      Kubernetes::Util.parse_file(raw_template, kubernetes_role.config_file)
    end

    def validate_config_file
      if build && kubernetes_role && raw_template.blank?
        errors.add(:build, "does not contain config file '#{kubernetes_role.config_file}'")
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
