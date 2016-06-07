module Kubernetes
  class Job < ActiveRecord::Base

    self.table_name = 'kubernetes_jobs'

    ACTIVE_STATUSES = %w[pending running cancelling].freeze
    VALID_STATUSES = ACTIVE_STATUSES + %w[failed errored succeeded cancelled].freeze

    belongs_to :build
    belongs_to :stage
    belongs_to :user
    has_many :job_docs
    belongs_to :kubernetes_task,
      inverse_of: :kubernetes_jobs,
      class_name: 'Kubernetes::Task',
      foreign_key: :kubernetes_task_id

    delegate :project, to: :stage

    validates :kubernetes_task, presence: true
    validates :status, presence: true, inclusion: VALID_STATUSES
    validates :commit, presence: true
    validates :stage, presence: true
    validates :user, presence: true
    validate :validate_git_reference, on: :create
    validate :validate_config_file, on: :create

    def raw_template
      @raw_template ||= build.file_from_repo(template_name)
    end

    def template_name
      kubernetes_task.config_file
    end

    def deploy
      nil
    end

    def output
      super || ""
    end

    def summary
      "#{user.name} run task #{kubernetes_task.name} #{short_reference} on #{stage.name}"
    end

    def summary_for_process
      t = (Time.now.to_i - start_time.to_i)
      "ProcessID: #{pid} Running task #{kubernetes_task.name}: #{t} seconds"
    end

    def project
      stage.project
    end

    def start_time
      created_at
    end

    def finished?
      !ACTIVE_STATUSES.include?(status)
    end

    def active?
      ACTIVE_STATUSES.include?(status)
    end

    %w[pending running succeeded cancelling cancelled failed errored].each do |status|
      define_method "#{status}?" do
        self.status == status
      end
    end

    def error!
      status!("errored")
    end

    def success!
      status!("succeeded")
    end

    def fail!
      status!("failed")
    end

    def run!
      status!("running")
    end

    def update_output!(output)
      update_attribute(:output, output)
    end

    def update_git_references!(commit:, tag:)
      update_columns(commit: commit, tag: tag)
    end

    def can_be_stopped_by?(user)
      started_by?(user) || user.admin? || user.admin_for?(project)
    end

    def started_by?(user)
      self.user == user
    end

    def job_selector(deploy_group)
      {
        job_id: id,
        deploy_group_id: deploy_group.id,
      }
    end

    private

    def status!(status)
      update_attribute(:status, status)
    end

    # Create new client as 'Batch' API is on different path then 'v1'
    def batch_client
      deploy_group.kubernetes_cluster.batch_client
    end

    def job_yaml
      @job_yaml ||= JobYaml.new(self)
    end

    # TODO: implement method
    def resource_running?(_resource)
      # batch_client.get_job(resource.metadata.name, resource.metadata.namespace)
      false
    rescue KubeException
      false
    end

    def parsed_config_file
      Array.wrap(Kubernetes::Util.parse_file(raw_template, template_name))
    end

    def validate_git_reference
      if commit.blank? && tag.blank?
        errors.add(:commit, 'must be specified')
        return
      end
    end

    def short_reference
      if commit =~ /\A[0-9a-f]{40}\Z/
        commit[0...7]
      else
        commit
      end
    end

    def pid
      execution.try :pid
    end

    def execution
      JobExecution.find_by_id(id)
    end

    def validate_config_file
      if build && kubernetes_task
        if raw_template.blank?
          errors.add(:build, "does not contain config file '#{template_name}'")
        end
      end
    end
  end
end
