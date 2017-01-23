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
    has_paper_trail skip: [:updated_at, :created_at]

    belongs_to :project, inverse_of: :kubernetes_roles
    has_many :kubernetes_deploy_group_roles,
      class_name: 'Kubernetes::DeployGroupRole',
      foreign_key: :kubernetes_role_id,
      dependent: :destroy

    before_validation :nilify_service_name
    before_validation :strip_config_file

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

    after_soft_delete :delete_kubernetes_deploy_group_roles

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
      return unless raw_template = project.repository.file_content(config_file, 'HEAD', pull: false)
      begin
        config = RoleConfigFile.new(raw_template, config_file)
      rescue Samson::Hooks::UserError
        return
      end

      config.elements.detect do |resource|
        next unless spec = resource[:spec]
        replicas = spec[:replicas] || 1

        next unless limits = spec.dig(:template, :spec, :containers, 0, :resources, :limits)
        next unless cpu = parse_resource_value(limits[:cpu])
        next unless ram = parse_resource_value(limits[:memory]) # TODO: rename this and the column to memory
        ram /= 1024**2 # we store megabyte

        break {cpu: cpu, ram: ram.round, replicas: replicas}
      end
    end

    private

    def nilify_service_name
      self.service_name = service_name.presence
    end

    def parse_resource_value(v)
      return unless v.to_s =~ /^(\d+(?:\.\d+)?)(#{KUBE_RESOURCE_VALUES.keys.join('|')})$/
      $1.to_f * KUBE_RESOURCE_VALUES.fetch($2)
    end

    def delete_kubernetes_deploy_group_roles
      kubernetes_deploy_group_roles.destroy_all
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
