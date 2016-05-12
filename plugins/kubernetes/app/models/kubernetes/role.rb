require 'soft_deletion'

module Kubernetes
  class Role < ActiveRecord::Base
    self.table_name = 'kubernetes_roles'

    has_soft_deletion

    belongs_to :project, inverse_of: :kubernetes_roles
    has_many :kubernetes_deploy_group_roles, class_name: 'Kubernetes::DeployGroupRole', dependent: :destroy

    DEPLOY_STRATEGIES = %w(RollingUpdate Recreate)

    validates :project, presence: true
    validates :name, presence: true
    validates :deploy_strategy, presence: true, inclusion: DEPLOY_STRATEGIES
    validates :replicas, presence: true, numericality: { greater_than: 0 }
    validates :ram, presence: true, numericality: { greater_than: 0 }
    validates :cpu, presence: true, numericality: { greater_than: 0 }
    validates :service_name, uniqueness: {scope: :deleted_at, allow_nil: true}

    scope :not_deleted, -> { where(deleted_at: nil) }

    # create initial roles for a project by reading kubernetes/*{.yml,.yaml,json} files into roles
    def self.seed!(project, git_ref)
      kubernetes_config_files_in_repo(project, git_ref).each do |config_file|
        service_name = config_file.service && config_file.service.metadata.name
        service_name << "-#{rand(9999999)}" if where(service_name: service_name).exists?

        create!(
          project: project,
          config_file: config_file.file_path,
          name: config_file.deployment.metadata.labels.role,
          service_name: service_name,
          ram: config_file.deployment.ram_mi, # TODO: remove this column
          cpu: config_file.deployment.cpu_m, # TODO: remove this column
          replicas: config_file.deployment.spec.replicas || 1, # TODO: remove this column
          deploy_strategy: config_file.deployment.strategy_type
        )
      end
    end

    def self.configured_for_project(project, git_sha)
      known = not_deleted.where(project: project)

      necessary_role_configs = kubernetes_config_files_in_repo(project, git_sha).map(&:file_path)
      necessary_role_configs.map do |file|
        known.detect { |r| r.config_file == file } || begin
          url = AppRoutes.url_helpers.project_kubernetes_roles_url(project)
          raise(
            Samson::Hooks::UserError,
            "No role for #{file} is configured. Add it on kubernetes Roles tab #{url}"
          )
        end
      end
    end

    def label_name
      name.parameterize('-')
    end

    def ram_with_units
      "#{ram}Mi" if ram.present?
    end

    def has_service?
      service_name.present?
    end

    def service_for(deploy_group)
      Kubernetes::Service.new(role: self, deploy_group: deploy_group) if has_service?
    end

    private

    class << self
      def kubernetes_config_files_in_repo(project, git_ref)
        path = 'kubernetes'
        files = project.repository.file_content(path, git_ref) || []
        files = files.split("\n").grep(/\.(yml|yaml|json)$/).map { |f| "#{path}/#{f}" }
        files.map do |file|
          file_contents = project.repository.file_content file, git_ref
          Kubernetes::RoleConfigFile.new(file_contents, file)
        end
      end
    end
  end
end
