require 'soft_deletion'

module Kubernetes
  class Task < ActiveRecord::Base
    self.table_name = 'kubernetes_tasks'
    GENERATED = '-CHANGE-ME-'.freeze

    has_soft_deletion

    belongs_to :project, inverse_of: :kubernetes_tasks
    has_many :kubernetes_jobs,
      -> { order(created_at: :desc) },
      foreign_key: 'kubernetes_task_id',
      class_name: 'Kubernetes::Job'

    has_many :kubernetes_deploy_group_roles,
      class_name: 'Kubernetes::DeployGroupRole',
      foreign_key: :kubernetes_role_id,
      dependent: :destroy

    validates :project, presence: true
    validates :name, presence: true

    scope :not_deleted, -> { where(deleted_at: nil) }

    # create initial roles for a project by reading kubernetes/jobs/*{.yml,.yaml,json} files into jobs
    def self.seed!(project, git_ref)
      kubernetes_config_files_in_repo(project, git_ref).each do |config_file|
        scope = where(project: project)
        next if scope.where(config_file: config_file.file_path).exists?

        name = config_file.job.metadata.labels.try(:task) || File.basename(config_file.file_path).sub(/\..*/, '')

        create!(
          project: project,
          config_file: config_file.file_path,
          name: name
        )
      end
    end

    def label_name
      name.parameterize
    end

    class << self
      private

      def kubernetes_config_files_in_repo(project, git_ref)
        path = 'kubernetes/tasks'
        files = project.repository.file_content(path, git_ref) || []
        files = files.split("\n").grep(/\.(yml|yaml|json)$/).map { |f| "#{path}/#{f}" }
        files.map do |file|
          file_contents = project.repository.file_content file, git_ref
          Kubernetes::TaskConfigFile.new(file_contents, file)
        end
      end
    end
  end
end
