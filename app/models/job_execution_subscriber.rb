# frozen_string_literal: true
class JobExecutionSubscriber
  def initialize(job, &block)
    @job = job
    @block = block
  end

  def call
    @block.call
  rescue => exception
    # ideally append errors to log here, but would not work for before hooks and
    # would not be streamed to the user for after hooks
    Airbrake.notify(
      exception,
      error_message: "JobExecutionSubscriber failed: #{exception.message}",
      parameters: { job_url: @job.url }
    )
  end
end
