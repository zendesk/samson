JobExecution.setup

if !Rails.env.test? && Job.table_exists?
  JobExecution.enabled = true

  Job.pending.each do |job|
    JobExecution.start_job(job.deploy.reference, job)
  end

  Signal.trap('SIGUSR1') do
    # Disable new job execution
    JobExecution.enabled = false

    until JobExecution.all.empty?
      puts "Waiting for jobs: #{JobExecution.all.map {|je| je.job.id}}"
      sleep(5)
    end

    # Pass USR2 to the underlying server
    Process.kill('SIGUSR2', $$)
  end
end
