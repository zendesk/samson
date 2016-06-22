require 'soft_deletion'

module Kubernetes
  class Task < ActiveRecord::Base
    FOLDER = 'kubernetes/jobs'

    self.table_name = 'kubernetes_tasks'

    has_soft_deletion

    belongs_to :project, inverse_of: :kubernetes_tasks
    has_many :kubernetes_jobs,
      -> { order(created_at: :desc) },
      foreign_key: 'kubernetes_task_id',
      class_name: 'Kubernetes::Job'

    validates :project, presence: true
    validates :name, presence: true

    scope :not_deleted, -> { where(deleted_at: nil) }

    # create initial roles for a project by reading kubernetes/jobs/*{.yml,.yaml,json} files into jobs
    # TODO: very similar to Role ... might be able to unify
    def self.seed!(project, git_ref)
      Kubernetes::Role.kubernetes_config_files_in_repo(project, FOLDER, git_ref).each do |config_file|
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
  end
end
