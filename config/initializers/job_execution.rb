if !Rails.env.test? && !ENV['PRECOMPILE']
  if ENV['SERVER_MODE']
    Rails.application.config.after_initialize do
      JobExecution.enabled = true

      if Job.table_exists?
        Job.running.each(&:stop!)

        Job.non_deploy.pending.each do |job|
          JobExecution.start_job(JobExecution.new(job.commit, job))
        end
      end

      if Deploy.table_exists?
        Deploy.active.each do |deploy|
          deploy.pending_start! if deploy.pending_non_production?
        end
      end
    end
  end

  handler = SignalHandler.new
  Signal.trap('SIGUSR1') { handler.signal }
end
