Rails.application.config.after_initialize do
  Job.pending.each do |job|
    JobExecution.start_job(job.deploy.reference, job)
  end
end

Signal.trap('USR1') do
  # Disable new job execution
  JobExecution.enabled = false
  sleep(5) until JobExecution.all.empty?

  # Pass USR2 to the underlying server
  Process.kill('USR2', $$)
end
