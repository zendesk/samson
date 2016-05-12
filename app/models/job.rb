class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  has_one :deploy

  # Used by status_panel
  alias_attribute :start_time, :created_at

  after_update { deploy.touch if deploy }

  validate :validate_globally_unlocked

  ACTIVE_STATUSES = %w[pending running cancelling].freeze
  VALID_STATUSES = ACTIVE_STATUSES + %w[failed errored succeeded cancelled].freeze

  def self.valid_status?(status)
    VALID_STATUSES.include?(status)
  end

  def self.non_deploy
    includes(:deploy).where(deploys: { id: nil })
  end

  def self.pending
    where(status: 'pending')
  end

  def self.running
    where(status: 'running')
  end

  def summary
    "#{user.name} #{summary_action} against #{short_reference}"
  end

  def summary_for_process
    t = (Time.now.to_i - start_time.to_i)
    "ProcessID: #{pid} Running: #{t} seconds"
  end

  def user
    super || NullUser.new(user_id)
  end

  def started_by?(user)
    self.user == user
  end

  def can_be_stopped_by?(user)
    started_by?(user) || user.admin? || user.admin_for?(project)
  end

  def commands
    command.split(/\r?\n|\r/)
  end

  def stop!
    if execution
      cancelling!
      execution.stop!
    else
      cancelled!
    end
  end

  %w{pending running succeeded cancelling cancelled failed errored}.each do |status|
    define_method "#{status}?" do
      self.status == status
    end
  end

  def run!
    status!("running")
  end

  def success!
    status!("succeeded")
  end

  def fail!
    status!("failed")
  end

  def error!
    status!("errored")
  end

  def cancelling!
    status!("cancelling")
  end

  def cancelled!
    status!("cancelled")
  end

  def finished?
    !ACTIVE_STATUSES.include?(status)
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def output
    super || ""
  end

  def update_output!(output)
    update_attribute(:output, output)
  end

  def update_git_references!(commit:, tag:)
    update_columns(commit: commit, tag: tag)
  end

  def url
    deploy.try(:url) || AppRoutes.url_helpers.project_job_url(project, self)
  end

  def pid
    execution.try :pid
  end

  private

  def validate_globally_unlocked
    if Lock.global.exists?
      errors.add(:project, 'is locked')
    end
  end

  def execution
    JobExecution.find_by_id(id)
  end

  def status!(status)
    update_attribute(:status, status)
  end

  def summary_action
    if pending?
      "is about to execute"
    elsif running?
      "is executing"
    elsif cancelling?
      "is cancelling an execution"
    elsif cancelled?
      "cancelled an execution"
    elsif succeeded?
      "executed"
    elsif failed?
      "failed to execute"
    elsif errored?
      "encountered an error executing"
    end
  end

  def short_reference
    if commit =~ /\A[0-9a-f]{40}\Z/
      commit[0...7]
    else
      commit
    end
  end
end
