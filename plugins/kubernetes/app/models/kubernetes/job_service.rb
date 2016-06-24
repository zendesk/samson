module Kubernetes
  class JobService
    include ::NewRelic::Agent::MethodTracer
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def run!(task, job_params)
      job = task.kubernetes_jobs.create(job_params.merge(user: user))

      if job.persisted?
        job_execution = JobExecution.new(job.commit, job) do |execution, _tmp_dir|
          @output = execution.output
          job_executor = JobExecutor.new(@output, job: job)
          job_executor.execute!
        end

        JobExecution.start_job(job_execution)
      end
      job
    end
  end
end
