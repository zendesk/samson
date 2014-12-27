if !Rails.env.test? && Job.table_exists?
  if ENV['SERVER_MODE']
    Rails.application.config.after_initialize do
      Job.running.each(&:stop!)
      JobExecution.enabled = true
    end
  end

  Signal.trap('SIGUSR1') do
    if JobExecution.enabled
      # Disable new job execution
      JobExecution.enabled = false

      until JobExecution.all.empty? && MultiLock.locks.empty?
        puts "Waiting for jobs: #{JobExecution.all.map {|je| je.job.id}}"
        sleep(5)
      end

      puts "Passing SIGUSR2 on."

      # Pass USR2 to the underlying server
      Process.kill('SIGUSR2', $$)
    end
  end
end
