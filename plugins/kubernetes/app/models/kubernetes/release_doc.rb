# frozen_string_literal: true
module Kubernetes
  class ReleaseDoc < ActiveRecord::Base
    self.table_name = 'kubernetes_release_docs'

    belongs_to :kubernetes_role, class_name: 'Kubernetes::Role'
    belongs_to :kubernetes_release, class_name: 'Kubernetes::Release'
    belongs_to :deploy_group

    serialize :resource_template, JSON
    delegate :desired_pod_count, to: :resource_object

    validates :deploy_group, presence: true
    validates :kubernetes_role, presence: true
    validates :kubernetes_release, presence: true
    validate :validate_config_file, on: :create

    before_save :store_resource_template, on: :create

    attr_reader :previous_deploy

    def build
      kubernetes_release.try(:build)
    end

    def job?
      resource.fetch(:kind) == 'Job'
    end

    def deploy
      @deployed = true
      @previous_deploy = resource_object.resource
      resource_object.deploy
    end

    def revert
      raise "Can only be done after a deploy" unless @deployed
      resource_object.revert(@previous_deploy)
      service&.revert(!!@previous_deploy)
    end

    def ensure_service
      if service.nil?
        'Service not defined'
      elsif service.running?
        # ideally we should update, but that is not supported
        # and delete+create would mean interrupting service
        # TODO: warn if the running definition does not match the requested definition
        'Service already running'
      else
        service.deploy
        'Service created'
      end
    end

    # run on unsaved mock ReleaseDoc to test template and secrets before we save or create a build
    def verify_template
      config = primary_resource(parsed_config_file.elements)
      template = Kubernetes::ResourceTemplate.new(self, config)
      template.set_secrets
    end

    # kubeclient needs pure symbol hash ... not indifferent access
    def resource_template
      @resource_template ||= Array.wrap(super).map(&:deep_symbolize_keys)
    end

    private

    def resource
      @resource ||= primary_resource(resource_template)
    end

    # TODO: rename to resource and other to primary_template
    def resource_object
      @resource_object ||= Kubernetes::Resource.build(resource, deploy_group)
    end

    def primary_resource(elements)
      Array.wrap(elements).detect do |config|
        Kubernetes::RoleConfigFile::PRIMARY.include?(config.fetch(:kind))
      end
    end

    def resource_template=(value)
      @resource_template = nil
      super
    end

    # dynamically fill out the templates and store the result
    def store_resource_template
      self.resource_template = parsed_config_file.elements.map do |resource|
        unless resource[:metadata][:namespace] == "kube-system"
          resource[:metadata][:namespace] = deploy_group.kubernetes_namespace
        end

        case resource[:kind]
        when 'Service'
          name = kubernetes_role.service_name
          if name.to_s.include?(Kubernetes::Role::GENERATED)
            raise(
              Samson::Hooks::UserError,
              "Service name for role #{kubernetes_role.name} was generated and needs to be changed before deploying."
            )
          end
          resource[:metadata][:name] = name.presence || resource[:metadata][:name]

          # For now, create a NodePort for each service, so we can expose any
          # apps running in the Kubernetes cluster to traffic outside the cluster.
          resource[:spec][:type] = 'NodePort'
          resource
        else
          ResourceTemplate.new(self, resource).to_hash
        end
      end
    end

    # TODO: handle as one of many secondary_resources
    def service
      return @service if defined?(@service)
      template = resource_template.detect { |t| t.fetch(:kind) == 'Service' }
      @service = template && Kubernetes::Resource.build(template, deploy_group)
    end

    def parsed_config_file
      @parsed_config_file ||= RoleConfigFile.new(raw_template, template_name)
    end

    def validate_config_file
      return if !build || !kubernetes_role
      parsed_config_file
    rescue Samson::Hooks::UserError
      errors.add(:kubernetes_release, $!.message)
    end

    def template_name
      kubernetes_role.config_file
    end

    def raw_template
      kubernetes_release.project.repository.file_content(template_name, kubernetes_release.git_sha)
    end
  end
end
