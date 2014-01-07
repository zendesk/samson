class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  def started_by?(user)
    self.user == user
  end

  def stop!
    status!("cancelling")
    execution.stop!
    status!("cancelled")
  end

  def start!
    status!("started")
  end

  def success!
    status!("succeeded")
  end

  def fail!
    status!("failed")
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
