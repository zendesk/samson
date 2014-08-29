JobExecution.setup

if !Rails.env.test? && Job.table_exists?
  JobExecution.enabled = true

  Rails.application.config.after_initialize do
    Job.running.each do |job|
      job.stop!
    end
  end

  Signal.trap('SIGUSR1') do
    if JobExecution.enabled
      # Disable new job execution
      JobExecution.enabled = false

      until JobExecution.all.empty?
        puts "Waiting for jobs: #{JobExecution.all.map {|je| je.job.id}}"
        sleep(5)
      end

      puts "Passing SIGUSR2 on."

      # Pass USR2 to the underlying server
      Process.kill('SIGUSR2', $$)
    else
      puts "Received USR1 at #{Time.now}. Dumping threads:"
      Thread.list.each do |t|
        trace = t.backtrace.join("\n")
        puts trace
        puts "---"
      end
    end
  end
end
