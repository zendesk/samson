JobExecution.setup

unless Rails.env.test? || File.basename($0) == "rake"
  JobExecution.enabled = true

  Job.pending.each do |job|
    JobExecution.start_job(job.deploy.reference, job)
  end

  Signal.trap('SIGUSR1') do
    # Disable new job execution
    JobExecution.enabled = false

    until JobExecution.all.empty?
      Rails.logger.info("Waiting for jobs: #{JobExecution.all.map {|je| je.job.id}}")
      sleep(5)
    end

    # Pass USR2 to the underlying server
    Process.kill('SIGUSR2', $$)
  end
end
