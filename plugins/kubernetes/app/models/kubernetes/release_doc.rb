# frozen_string_literal: true
module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    serialize :resource_template, JSON
    delegate :desired_pod_count, :prerequisite?, to: :primary_resource

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_save :store_resource_template, on: :create

    attr_reader :previous_resources

    def deploy
      @previous_resources = resources.map(&:resource)
      resources.each(&:deploy)
    end

    def revert
      raise "Can only be done after a deploy" unless @previous_resources
      resources.each_with_index do |resource, i|
        resource.revert(@previous_resources[i])
      end
    end

    # run on unsaved mock ReleaseDoc to test template and secrets before we save or create a build
    # this create a bit of duplicated work, but fails the deploy fast
    def verify_template
      primary_config = raw_template.detect { |e| Kubernetes::RoleConfigFile::PRIMARY_KINDS.include?(e.fetch(:kind)) }
      template = Kubernetes::TemplateFiller.new(self, primary_config)
      template.set_secrets
      template.verify_env
    end

    # kubeclient needs pure symbol hash ... not indifferent access
    def resource_template
      @resource_template ||= Array.wrap(super).map(&:deep_symbolize_keys)
    end

    def resources
      @resources ||= resource_template.map do |t|
        Kubernetes::Resource.build(t, deploy_group)
      end
    end

    private

    def primary_resource
      resources.detect(&:primary?)
    end

    def resource_template=(value)
      @resource_template = nil
      super
    end

    # dynamically fill out the templates and store the result
    def store_resource_template
      self.resource_template = raw_template.map do |resource|
        update_namespace resource

        case resource[:kind]
        when 'Service'
          resource[:metadata][:name] = generate_service_name(resource[:metadata][:name])

          prefix_service_cluster_ip(resource)

          # For now, create a NodePort for each service, so we can expose any
          # apps running in the Kubernetes cluster to traffic outside the cluster.
          resource[:spec][:type] = 'NodePort'
          resource
        when *Kubernetes::RoleConfigFile::PRIMARY_KINDS
          make_stateful_set_match_service(resource)
          TemplateFiller.new(self, resource).to_hash
        else
          resource
        end
      end
    end

    # If the user renames the service the StatefulSet will not match it, so we fix.
    # Will not work with multiple services ... but that usecase hopefully does not exist.
    def make_stateful_set_match_service(resource)
      return unless resource[:kind] == "StatefulSet"
      return unless resource[:spec][:serviceName]
      return unless service_name = kubernetes_role.service_name.presence
      resource[:spec][:serviceName] = service_name
    end

    def generate_service_name(config_name)
      return config_name unless name = kubernetes_role.service_name.presence
      if name.include?(Kubernetes::Role::GENERATED)
        raise(
          Samson::Hooks::UserError,
          "Service name for role #{kubernetes_role.name} was generated and needs to be changed before deploying."
        )
      end

      # users can only enter a single service-name so for each additional service we make up a name
      # unless the given name already fits the pattern ... slight chance that it might end up being not unique
      return config_name if config_name.start_with?(name)

      @service_names_generated ||= 0
      @service_names_generated += 1
      name += "-#{@service_names_generated}" if @service_names_generated >= 2
      name
    end

    # no ipv6 support
    def prefix_service_cluster_ip(resource)
      return unless ip = resource[:spec][:clusterIP]
      return if ip == "None"
      return unless prefix = deploy_group.kubernetes_cluster.ip_prefix.presence
      ip = ip.split('.')
      prefix = prefix.split('.')
      ip[0...prefix.size] = prefix
      resource[:spec][:clusterIP] = ip.join('.')
    end

    def update_namespace(resource)
      system_namespaces = ["default", "kube-system"]
      return if system_namespaces.include?(resource[:metadata][:namespace]) &&
        (resource[:metadata][:labels] || {})[:'kubernetes.io/cluster-service'] == 'true'
      resource[:metadata][:namespace] = deploy_group.kubernetes_namespace
    end

    def validate_config_file
      return unless kubernetes_role
      raw_template # trigger RoleConfigFile validations
    rescue Samson::Hooks::UserError
      errors.add(:kubernetes_release, $!.message)
    end

    def raw_template
      @raw_template ||= begin
        file = kubernetes_role.config_file
        content = kubernetes_release.project.repository.file_content(file, kubernetes_release.git_sha)
        RoleConfigFile.new(content, file).elements
      end
    end
  end
end
