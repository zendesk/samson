# frozen_string_literal: true

ActiveSupport::TestCase.class_eval do
  # when job execution is on jobs can end up in the queue and that can break future tests
  # so we clean after using JobExecution
  def with_job_execution
    JobExecution.enabled = true
    yield
  ensure
    JobExecution.send(:job_queue).instance_variable_get(:@queue).clear
    JobExecution.send(:job_queue).instance_variable_get(:@active).clear
    JobExecution.enabled = false
  end

  def self.with_job_execution
    around { |t| with_job_execution(&t) }
  end

  def self.with_job_stop_timeout(value)
    around do |test|
      begin
        old = JobExecution.stop_timeout
        JobExecution.stop_timeout = value
        test.call
      ensure
        JobExecution.stop_timeout = old
      end
    end
  end

  def self.with_full_job_execution
    with_job_execution
    with_job_stop_timeout 0.1
    with_project_on_remote_repo
    around { |t| ArMultiThreadedTransactionalTests.activate &t }
  end
end
