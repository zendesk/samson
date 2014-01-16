JobExecution.setup

unless Rails.env.test?
  Job.pending.each do |job|
    JobExecution.start_job(job.deploy.reference, job)
  end

  Signal.trap('SIGUSR1') do
    # Disable new job execution
    JobExecution.enabled = false
    sleep(5) until JobExecution.all.empty?

    # Pass USR2 to the underlying server
    Process.kill('SIGUSR2', $$)
  end
end
