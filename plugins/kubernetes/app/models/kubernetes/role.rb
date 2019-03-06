# frozen_string_literal: true
require 'soft_deletion'

module Kubernetes
  class Role < ActiveRecord::Base
    # https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-memory
    # TL;DR:
    # You can express memory as a plain integer or as a fixed-point integer using one of these
    # suffixes: E, P, T, G, M, K. You can also use the power-of-two equivalents: Ei, Pi, Ti, Gi, Mi, Ki.
    KUBE_MEMORY_VALUES = {
      "" => 1,
      'K' => 1000,
      'Ki' => 1024,
      'M' => 1000**2,
      'Mi' => 1024**2,
      'G' => 1000**3,
      'Gi' => 1024**3
    }.freeze
    KUBE_CPU_VALUES = {
      "" => 1,
      'm' => 0.001
    }.freeze

    self.table_name = 'kubernetes_roles'
    GENERATED = '-change-me-'

    has_soft_deletion
    audited

    include SoftDeleteWithDestroy

    belongs_to :project, inverse_of: :kubernetes_roles
    has_many :kubernetes_deploy_group_roles,
      class_name: 'Kubernetes::DeployGroupRole',
      foreign_key: :kubernetes_role_id,
      dependent: :destroy
    has_many :stage_roles,
      class_name: "Kubernetes::StageRole",
      foreign_key: :kubernetes_role_id,
      dependent: :destroy

    before_validation :nilify_service_name
    before_validation :strip_config_file

    validates :project, presence: true
    validates :name, presence: true, format: Kubernetes::RoleValidator::VALID_LABEL_VALUE
    validates :service_name,
      uniqueness: {scope: :deleted_at, allow_nil: true},
      format: Kubernetes::RoleValidator::VALID_LABEL_VALUE,
      allow_nil: true
    validates :resource_name,
      uniqueness: {scope: :deleted_at, allow_nil: true},
      format: Kubernetes::RoleValidator::VALID_LABEL_VALUE
    validates :manual_deletion_acknowledged, presence: {message: "must be set"}, if: :manual_deletion_required?

    scope :not_deleted, -> { where(deleted_at: nil) }

    attr_accessor :manual_deletion_acknowledged

    # create initial roles for a project by reading kubernetes/*{.yml,.yaml,json} files into roles
    def self.seed!(project, git_ref)
      configs = kubernetes_config_files_in_repo(project, git_ref)
      if configs.empty?
        raise Samson::Hooks::UserError, "No configs found in kubernetes folder or invalid git ref #{git_ref}"
      end

      configs.each do |config_file|
        scope = where(project: project)

        next if scope.where(config_file: config_file.path, deleted_at: nil).exists?
        resource = config_file.primary
        name = resource.fetch(:metadata).fetch(:labels).fetch(:role)

        # service
        if service = config_file.services.first
          service_name = service[:metadata][:name]
          if where(service_name: service_name).exists?
            service_name << "#{GENERATED}#{rand(9999999)}"
          end
        end

        # ensure we have a unique resource name
        resource_name = resource.fetch(:metadata).fetch(:name)
        if where(resource_name: resource_name).exists?
          resource_name = "#{project.permalink}-#{resource_name}".tr('_', '-')
        end

        project.kubernetes_roles.create!(
          config_file: config_file.path,
          name: name,
          resource_name: resource_name,
          service_name: service_name
        )
      end
    end

    # roles for which a config file exists in the repo
    # ... we ignore those without to allow users to deploy a branch that changes roles
    def self.configured_for_project(project, git_sha)
      project.kubernetes_roles.not_deleted.select do |role|
        path = role.config_file
        next unless file_contents = project.repository.file_content(path, git_sha)
        Kubernetes::RoleConfigFile.new(file_contents, path) # run validations
      end
    end

    def defaults
      return unless resource = role_config_file('HEAD')&.primary
      spec = resource.fetch(:spec)
      if resource[:kind] == "Pod"
        replicas = 0 # these are one-off tasks most of the time, so we should not count them in totals
      else
        replicas = spec[:replicas] || 1
        spec = spec.dig(:template, :spec) || {}
      end

      return unless limits = spec.dig(:containers, 0, :resources, :limits)
      return unless limits_cpu = parse_resource_value(limits[:cpu], KUBE_CPU_VALUES)
      return unless limits_memory = parse_resource_value(limits[:memory], KUBE_MEMORY_VALUES)
      limits_memory /= 1000**2 # we store megabyte

      if requests = spec.dig(:containers, 0, :resources, :requests)
        requests_cpu = parse_resource_value(requests[:cpu], KUBE_CPU_VALUES)
        if requests_memory = parse_resource_value(requests[:memory], KUBE_MEMORY_VALUES)
          requests_memory /= 1000**2 # we store megabyte
        end
      end

      {
        limits_cpu: limits_cpu,
        limits_memory: limits_memory.round,
        requests_cpu: requests_cpu || limits_cpu,
        requests_memory: (requests_memory || limits_memory).round,
        replicas: replicas
      }
    end

    def role_config_file(reference)
      return unless raw_template = project.repository.file_content(config_file, reference, pull: false)
      begin
        RoleConfigFile.new(raw_template, config_file)
      rescue Samson::Hooks::UserError
        nil
      end
    end

    def manual_deletion_required?
      resource_name_change&.first || service_name_change&.first
    end

    private

    def nilify_service_name
      self.service_name = service_name.presence
    end

    def parse_resource_value(v, possible)
      return unless v.to_s =~ /^(\d+(?:\.\d+)?)(#{possible.keys.join('|')})$/
      $1.to_f * possible.fetch($2)
    end

    def strip_config_file
      self.config_file = config_file.to_s.strip
    end

    class << self
      # all configs in kubernetes/* at given ref
      def kubernetes_config_files_in_repo(project, git_ref)
        folder = 'kubernetes'
        files = project.repository.file_content(folder, git_ref).
          to_s.split("\n").
          map { |f| "#{folder}/#{f}" }

        files.grep(/\.(yml|yaml|json)$/).map do |path|
          next unless file_contents = project.repository.file_content(path, git_ref)
          Kubernetes::RoleConfigFile.new(file_contents, path)
        end.compact
      end
    end
  end
end
