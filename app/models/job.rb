class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  has_one :deploy

  def self.pending
    where(status: 'pending')
  end

  def started_by?(user)
    self.user == user
  end

  def viewers
    Thread.main[:viewers] ||= ThreadSafe::Cache.new
    Thread.main[:viewers][job.id] ||= ThreadSafe::Array.new
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
    pending? || running?
  end

  def output
    super || ""
  end

  def update_output!(output)
    update_attribute(:output, output)
  end

  def update_commit!(commit)
    update_attribute(:commit, commit)
  end

  private

  def execution
    JobExecution.find_by_job(self)
  end

  def status!(status)
    update_attribute(:status, status)
  end
end
