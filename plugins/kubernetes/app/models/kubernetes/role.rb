# frozen_string_literal: true
require 'soft_deletion'

module Kubernetes
  class Role < ActiveRecord::Base
    KUBE_RESOURCE_VALUES = {
      "" => 1,
      'm' => 0.001,
      'K' => 1024,
      'Ki' => 1000,
      'M' => 1024**2,
      'Mi' => 1000**2,
      'G' => 1024**3,
      'Gi' => 1000**3
    }.freeze

    self.table_name = 'kubernetes_roles'
    GENERATED = '-change-me-'

    has_soft_deletion

    belongs_to :project, inverse_of: :kubernetes_roles
    has_many :kubernetes_deploy_group_roles,
      class_name: 'Kubernetes::DeployGroupRole',
      foreign_key: :kubernetes_role_id,
      dependent: :destroy

    before_validation :nilify_service_name

    validates :project, presence: true
    validates :name, presence: true, format: Kubernetes::RoleVerifier::VALID_LABEL
    validates :service_name,
      uniqueness: {scope: :deleted_at, allow_nil: true},
      format: Kubernetes::RoleVerifier::VALID_LABEL,
      allow_nil: true
    validates :resource_name,
      uniqueness: {scope: :deleted_at, allow_nil: true},
      format: Kubernetes::RoleVerifier::VALID_LABEL

    scope :not_deleted, -> { where(deleted_at: nil) }

    # create initial roles for a project by reading kubernetes/*{.yml,.yaml,json} files into roles
    def self.seed!(project, git_ref)
      configs = kubernetes_config_files_in_repo(project, git_ref)
      if configs.empty?
        raise Samson::Hooks::UserError, "No configs found in kubernetes folder or invalid git ref #{git_ref}"
      end

      configs.each do |config_file|
        scope = where(project: project)

        next if scope.where(config_file: config_file.path, deleted_at: nil).exists?
        deploy = (config_file.deploy || config_file.job)

        # deploy / job
        name = deploy.fetch(:metadata).fetch(:labels).fetch(:role)

        # service
        if service = config_file.service
          service_name = service[:metadata][:name]
          if where(service_name: service_name).exists?
            service_name << "#{GENERATED}#{rand(9999999)}"
          end
        end

        # ensure we have a unique resource name
        resource_name = deploy.fetch(:metadata).fetch(:name)
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

    def self.configured_for_project(project, git_sha)
      known = not_deleted.where(project: project)

      necessary_role_configs = kubernetes_config_files_in_repo(project, git_sha).map(&:path)
      necessary_role_configs.map do |path|
        known.detect { |r| r.config_file == path } || begin
          url = Rails.application.routes.url_helpers.project_kubernetes_roles_url(project)
          raise(
            Samson::Hooks::UserError,
            "No role for #{path} is configured. Add it on kubernetes Roles tab #{url}"
          )
        end
      end
    end

    def defaults
      return unless raw_template = project.repository.file_content(config_file, 'HEAD', pull: false)
      deploy = begin
        RoleConfigFile.new(raw_template, config_file).deploy || return
      rescue Samson::Hooks::UserError
        return
      end

      replicas = deploy[:spec][:replicas]

      return unless limits = deploy[:spec][:template][:spec][:containers].first.fetch(:resources, {})[:limits]
      return unless cpu = parse_resource_value(limits[:cpu])
      return unless ram = parse_resource_value(limits[:memory]) # TODO: rename this and the column to memory
      ram /= 1024**2 # we store megabyte

      {cpu: cpu, ram: ram.round, replicas: replicas}
    end

    private

    def nilify_service_name
      self.service_name = service_name.presence
    end

    def parse_resource_value(v)
      return unless v.to_s =~ /^(\d+(?:\.\d+)?)(#{KUBE_RESOURCE_VALUES.keys.join('|')})$/
      $1.to_f * KUBE_RESOURCE_VALUES.fetch($2)
    end

    class << self
      def kubernetes_config_files_in_repo(project, git_ref)
        path = 'kubernetes'
        files = project.repository.file_content(path, git_ref) || []

        files = files.split("\n").grep(/\.(yml|yaml|json)$/).map { |f| "#{path}/#{f}" }
        files.concat project.kubernetes_roles.map(&:config_file).
          reject { |f| f.start_with?("#{path}/") }

        files.map do |path|
          next unless file_contents = project.repository.file_content(path, git_ref)
          Kubernetes::RoleConfigFile.new(file_contents, path)
        end.compact
      end
    end
  end
end
