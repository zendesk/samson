class JobExecutionSubscriber
  def initialize(job, block)
    @job = job
    @block = block
  end

  def call
    @block.call
  rescue => e
    message = "JobExecutionSubscriber failed: #{exception.message}"

    Airbrake.notify(exception,
      error_message: message,
      parameters: {
        job_id: @job.id
      }
    )
  end
end
