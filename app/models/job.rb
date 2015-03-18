class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  has_one :deploy

  after_update { deploy.touch if deploy }

  validate :validate_globally_unlocked

  ACTIVE_STATUSES = %w[pending running cancelling].freeze

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

  def user
    super || NullUser.new(user_id)
  end

  def started_by?(user)
    self.user == user
  end

  def commands
    command.split(/\r?\n|\r/)
  end

  def stop!
    status!("cancelling")
    execution.try(:stop!)
    status!("cancelled")
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

  def finished?
    succeeded? || failed? || errored? || cancelled?
  end

  def active?
    pending? || running? || cancelling?
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
