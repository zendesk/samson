if !Rails.env.test? && !ENV['PRECOMPILE']
  if ENV['SERVER_MODE']
    Rails.application.config.after_initialize do
      if Job.table_exists?
        Job.running.each(&:stop!)

        Job.non_deploy.pending.each do |job|
          JobExecution.start_job(job.commit, job)
        end
      end

      if Deploy.table_exists?
        Deploy.active.each do |deploy|
          next unless deploy.pending_non_production?
          deploy.pending_start!
        end
      end

      JobExecution.enabled = true
    end
  end

  Signal.trap('SIGUSR1') do
    if JobExecution.enabled
      # Disable new job execution
      JobExecution.enabled = false

      until JobExecution.active.empty? && MultiLock.locks.empty?
        puts "Waiting for jobs: #{JobExecution.active.map(&:id)}"
        sleep(5)
      end

      puts "Passing SIGUSR2 on."

      # Pass USR2 to the underlying server
      Process.kill('SIGUSR2', $$)
    end
  end
end
