class JobExecutionSubscriber
  def initialize(job, block)
    @job = job
    @block = block
  end

  def call
    @block.call
  rescue => e
    Airbrake.notify(exception,
      error_message: "JobExecutionSubscriber failed: #{exception.message}",
      parameters: { job_id: @job.id }
    )
  end
end
