# frozen_string_literal: true
class Job < ActiveRecord::Base
  belongs_to :project, inverse_of: :jobs
  belongs_to :user, -> { unscope(where: :deleted_at) }, inverse_of: :jobs
  belongs_to :canceller, -> { unscope(where: "deleted_at") },
    class_name: 'User', optional: true, inverse_of: false

  has_one :deploy, dependent: nil
  has_one :build, dependent: nil, inverse_of: :docker_build_job

  # Used by status_panel
  alias_attribute :start_time, :created_at

  after_update { deploy&.touch }

  validate :validate_globally_unlocked

  attr_accessor :bypass_global_lock_check

  ACTIVE_STATUSES = ['pending', 'running', 'cancelling'].freeze
  VALID_STATUSES = ACTIVE_STATUSES + ['failed', 'errored', 'succeeded', 'cancelled'].freeze
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
    joins('left join deploys on deploys.job_id = jobs.id').where(deploys: {id: nil})
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

  def duration
    updated_at - created_at
  end

  def commands
    commands = []
    raw = command.split(/\r?\n|\r/)
    while c = raw.shift
      c << "\n" << raw.shift if c.match?(/\\ *\z/) # join multiline commands
      commands << c
    end
    commands
  end

  def cancel(canceller)
    !JobQueue.dequeue(id) && ex = execution # is executing
    return true if !ex && !active?

    update_attribute(:canceller, canceller) unless self.canceller # uncovered

    if ex
      JobQueue.cancel(id) # switches job status in the runner thread for consistent status in after_deploy hooks
    else
      cancelled!
    end
  end

  VALID_STATUSES.each do |status|
    define_method "#{status}?" do
      self.status == status
    end

    define_method "#{status}!" do
      status!(status)
    end
  end

  def finished?
    !ACTIVE_STATUSES.include?(status)
  end

  def queued?
    JobQueue.queued?(id)
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def executing?
    JobQueue.executing?(id)
  end

  def kubernetes?
    deploy && defined?(SamsonKubernetes::SamsonPlugin) && deploy&.stage&.kubernetes
  end

  def waiting_for_restart?
    !JobQueue.enabled && pending?
  end

  def output
    super || ""
  end

  def update_git_references!(commit:, tag:)
    update_columns(commit: commit, tag: tag)
    deploy&.bump_touch
  end

  def url
    deploy&.url || Rails.application.routes.url_helpers.project_job_url(project, self)
  end

  def pid
    execution&.pid
  end

  # set current incomplete output
  def serialize_execution_output
    return unless ex = execution
    out = ex.output.closed_copy
    self.output = TerminalOutputScanner.new(out).to_s
  end

  private

  def validate_globally_unlocked
    return if bypass_global_lock_check
    return unless lock = Lock.global.first
    return if lock.warning?
    errors.add(:base, 'all stages are locked')
  end

  def execution
    JobQueue.find_by_id(id)
  end

  def status!(status)
    hacky_update_attribute(:status, status)
    report_state if finished?
    true
  end

  # TODO: use update_attribute instead if this hack once we figure out why it causes nil errors see #3662 + #3664
  def hacky_update_attribute(key, value)
    update_columns(key => value, updated_at: Time.now)
    # same as after_update where touch cascades to stage
    deploy&.update_column(:updated_at, Time.now)
    deploy&.stage&.update_column(:updated_at, Time.now)
  end

  def short_reference
    if commit&.match?(Build::SHA1_REGEX)
      commit.slice(0, 7)
    else
      commit
    end
  end

  def report_state
    payload = {
      stage: deploy&.stage&.permalink,
      kubernetes: kubernetes?,
      project: project.permalink,
      type: deploy ? 'deploy' : 'build',
      status: status,
      cycle_time: DeployMetrics.new(deploy).cycle_time
    }
    ActiveSupport::Notifications.instrument('job_status.samson', payload)
  end
end
Samson::Hooks.load_decorators(Job)
