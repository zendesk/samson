# frozen_string_literal: true
class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user, -> { unscope(where: :deleted_at) }
  belongs_to :canceller, -> { unscope(where: "deleted_at") }, class_name: 'User'

  has_one :deploy

  # Used by status_panel
  alias_attribute :start_time, :created_at

  after_update { deploy&.touch }

  validate :validate_globally_unlocked

  ACTIVE_STATUSES = %w[pending running cancelling].freeze
  VALID_STATUSES = ACTIVE_STATUSES + %w[failed errored succeeded cancelled].freeze
  SUMMARY_ACTION = {
    "pending"    => "is about to execute",
    "running"    => "is executing",
    "succeeded"  => "executed",
    "failed"     => "failed to execute",
    "errored"    => "encountered an error executing"
  }.freeze

  def self.valid_status?(status)
    VALID_STATUSES.include?(status)
  end

  def self.non_deploy
    joins('left join deploys on deploys.job_id = jobs.id').where(deploys: { id: nil })
  end

  def self.pending
    where(status: 'pending')
  end

  def self.running
    where(status: 'running')
  end

  # deploy has almost identical code, keep it in sync
  def summary
    if ["cancelled", "cancelling"].include?(status)
      "Execution by #{user.name} against #{short_reference} is #{status}"
    else
      "#{user.name} #{SUMMARY_ACTION.fetch(status)} against #{short_reference}"
    end
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

  def stop!(canceller)
    update_attribute(:canceller, canceller) unless self.canceller

    if !JobExecution.dequeue(id) && ex = execution # is active
      cancelling!
      ex.stop!
    end

    cancelled!
  end

  %w[pending running succeeded cancelling cancelled failed errored].each do |status|
    define_method "#{status}?" do
      self.status == status # rubocop:disable Style/RedundantSelf
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

  def finished?
    !ACTIVE_STATUSES.include?(status)
  end

  def queued?
    pending? && JobExecution.queued?(id)
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def executing?
    active? || JobExecution.active?(id)
  end

  def waiting_for_restart?
    !JobExecution.enabled && pending?
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
    deploy&.url || Rails.application.routes.url_helpers.project_job_url(project, self)
  end

  def pid
    execution.try :pid
  end

  private

  def cancelling!
    status!("cancelling")
  end

  def cancelled!
    status!("cancelled")
  end

  def validate_globally_unlocked
    return unless lock = Lock.global.first
    return if lock.warning?
    errors.add(:base, 'all stages are locked')
  end

  def execution
    JobExecution.find_by_id(id)
  end

  def status!(status)
    update_attribute(:status, status)
  end

  def short_reference
    if commit =~ Build::SHA1_REGEX
      commit.slice(0, 7)
    else
      commit
    end
  end
end
