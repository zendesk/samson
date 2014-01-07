class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  def started_by?(user)
    self.user == user
  end

  def commands
    command.split("\n")
  end

  def stop!
    status!("cancelling")
    execution.try(:stop!)
    status!("cancelled")
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

  def pending?
    status == "pending"
  end

  def running?
    status == "running"
  end

  def succeeded?
    status == "succeeded"
  end

  def cancelling?
    status == "cancelling"
  end

  def failed?
    status == "failed"
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

  private

  def execution
    JobExecution.find_by_job(self)
  end

  def status!(status)
    update_attribute(:status, status)
  end
end
