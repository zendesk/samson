# frozen_string_literal: true

ActiveSupport::TestCase.class_eval do
  # when job execution is on jobs can end up in the queue and that can break future tests
  # so we clean after using JobExecution
  def with_job_execution
    JobQueue.enabled = true
    yield
  ensure
    JobQueue.enabled = false
    JobQueue.clear
  end

  def self.with_job_execution
    around { |t| with_job_execution(&t) }
  end

  def self.with_job_cancel_timeout(value)
    around do |test|
      begin
        old = JobExecution.cancel_timeout
        JobExecution.cancel_timeout = value
        test.call
      ensure
        JobExecution.cancel_timeout = old
      end
    end
  end

  def self.with_full_job_execution
    with_job_execution
    with_job_cancel_timeout 0.1
    with_project_on_remote_repo
    around { |t| ArMultiThreadedTransactionalTests.activate &t }
  end

  def wait_for_jobs_to_finish
    sleep 0.01 until JobQueue.debug == [{}, {}]
  end

  def wait_for_jobs_to_start
    sleep 0.01 until JobQueue.executing.any?
  end

  def with_blocked_jobs(count)
    with_job_execution do
      begin
        lock = Mutex.new.lock
        JobExecution.any_instance.expects(:perform).times(count).with { lock.synchronize { true } }
        yield
      ensure
        lock.unlock
        wait_for_jobs_to_finish
      end
    end
  end
end
