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
    MIN_MEMORY = 6

    self.table_name = 'kubernetes_roles'
    GENERATED = '-change-me-'

    has_soft_deletion
    audited

    include SoftDeleteWithDestroy
    delegate :override_resource_names?, to: :project

    belongs_to :project, inverse_of: :kubernetes_roles
    has_many :kubernetes_deploy_group_roles,
      class_name: 'Kubernetes::DeployGroupRole',
      foreign_key: :kubernetes_role_id,
      dependent: :destroy,
      inverse_of: :kubernetes_role
    has_many :stage_roles,
      class_name: "Kubernetes::StageRole",
      foreign_key: :kubernetes_role_id,
      dependent: :destroy,
      inverse_of: :kubernetes_role

    before_validation :nilify_service_name
    before_validation :strip_config_file

    validates :project, presence: true
    validates :name, presence: true, format: Kubernetes::RoleValidator::VALID_CONTAINER_NAME
    validates :service_name,
      uniqueness: {case_sensitive: false, scope: :deleted_at},
      format: Kubernetes::RoleValidator::VALID_CONTAINER_NAME,
      allow_nil: true
    validates :resource_name,
      uniqueness: {case_sensitive: false, scope: :deleted_at},
      format: Kubernetes::RoleValidator::VALID_CONTAINER_NAME,
      allow_nil: true
    validates :manual_deletion_acknowledged, presence: {message: "must be set"}, if: :manual_deletion_required?

    scope :not_deleted, -> { where(deleted_at: nil) }

    attr_accessor :manual_deletion_acknowledged

    class << self
      # create initial roles for a project by reading kubernetes/*{.yml,.yaml,json} files into roles
      # TODO: support dynamic folders
      def seed!(project, git_ref)
        configs = kubernetes_config_files_in_repo(project, git_ref)
        if configs.empty?
          raise Samson::Hooks::UserError, "No configs found in kubernetes/ folder or invalid git ref #{git_ref}"
        end
        existing = where(project: project, deleted_at: nil).to_a

        configs.each do |config_file|
          # ignore existing role
          next if existing.any? { |r| r.config_file == config_file.path }

          resource = config_file.primary || config_file.elements.first
          name = resource.dig_fetch(:metadata, :labels, :role)

          if project.override_resource_names?
            resource_name = seed_resource_name project, resource
            service_name = seed_service_name config_file
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
      def configured_for_project(project, git_sha)
        project.kubernetes_roles.not_deleted.select do |role|
          role.role_config_file(
            git_sha,
            project: project, ignore_missing: true, pull: true, deploy_group: nil
          )
        end
      end

      private

      # ensure we have a globally unique resource name
      def seed_resource_name(project, resource)
        resource_name = resource.dig_fetch(:metadata, :name)
        if where(deleted_at: nil, resource_name: resource_name).exists?
          resource_name = "#{project.permalink}-#{resource_name}".tr('_', '-')
        end
        resource_name
      end

      def seed_service_name(config_file)
        return unless service = config_file.services.first
        service_name = service.dig_fetch(:metadata, :name)
        # ensure we have a globally unique service name
        if service_name && where(deleted_at: nil, service_name: service_name).exists?
          service_name << "#{GENERATED}#{rand(9999999)}"
        end
        service_name
      end
    end

    # TODO: support dynamic folders
    def defaults
      reference = project.release_branch.presence || ResourceController::DEFAULT_BRANCH
      unless resource = role_config_file(reference, deploy_group: nil).primary
        return {replicas: 1, requests_cpu: 0, requests_memory: MIN_MEMORY, limits_cpu: 0.01, limits_memory: MIN_MEMORY}
      end
      spec = RoleConfigFile.templates(resource).dig(0, :spec) || raise # primary always has templates

      replicas =
        if resource[:kind] == "Pod"
          0 # these are one-off tasks most of the time, so we should not count them in totals
        else
          resource.dig(:spec, :replicas) || 1
        end

      if requests = spec.dig(:containers, 0, :resources, :requests)
        requests_cpu = parse_resource_value(requests[:cpu], KUBE_CPU_VALUES)
        requests_memory = parse_memory_value(requests)
      end

      return unless limits = spec.dig(:containers, 0, :resources, :limits)
      return unless limits_cpu = parse_resource_value(limits[:cpu], KUBE_CPU_VALUES)
      return unless limits_memory = parse_memory_value(limits)

      {
        requests_cpu: requests_cpu || limits_cpu,
        requests_memory: (requests_memory || limits_memory).round,
        replicas: replicas,
        limits_cpu: limits_cpu,
        limits_memory: limits_memory.round,
      }
    end

    # allows passing the project to reuse the repository cache when doing multiple lookups
    def role_config_file(reference, deploy_group:, project: project(), **args) # rubocop:disable Style/MethodCallWithoutArgsParentheses
      file = config_file
      if deploy_group && dynamic_folders?
        file = file.
          sub('$deploy_group_permalink', deploy_group.permalink).
          sub('$deploy_group', deploy_group.env_value).
          sub('$environment', deploy_group.environment.permalink)
      end

      self.class.role_config_file(project, file, reference, **args)
    end

    def manual_deletion_required?
      resource_name_change&.first || service_name_change&.first
    end

    def dynamic_folders?
      config_file.include?("$")
    end

    def parse_memory_value(limits)
      return unless bytes = parse_resource_value(limits[:memory], KUBE_MEMORY_VALUES)
      bytes / KUBE_MEMORY_VALUES.fetch("Mi")
    end

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
        paths = project.repository.
          file_content(folder, git_ref).
          to_s. # nil when not found
          split("\n")[2..] || []
        paths.map! { |f| "#{folder}/#{f}" }

        files = paths.grep(/\.(yml|yaml|json)$/)

        files.map! { |path| role_config_file(project, path, git_ref) }
      end

      # find and validate config or blow up with Samson::Hooks::UserError
      def role_config_file(project, path, git_ref, ignore_missing: false, pull: false)
        raw_template = project.repository.file_content(path, git_ref, pull: pull)
        return nil if ignore_missing && !raw_template
        Kubernetes::RoleConfigFile.new(raw_template, path, project: project)
      end
    end
  end
end
