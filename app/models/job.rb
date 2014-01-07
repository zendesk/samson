class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :user

  def started_by?(user)
    self.user == user
  end

  def stop!
    status!("cancelling")
    execution.stop! rescue nil
    status!("cancelled")
  end

  def output
    super || ""
  end

  private

  def execution
    JobExecution.find_by_job(self)
  end

  def status!(status)
    update_attribute(:status, status)
  end
end
