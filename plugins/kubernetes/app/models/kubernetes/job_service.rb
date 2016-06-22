module Kubernetes
  class JobService
    include ::NewRelic::Agent::MethodTracer

    def initialize(job)
      @job = job
    end

    def run!
      job_execution = ::JobExecution.new(@job.commit, @job) do |execution, _tmp_dir|
        @output = execution.output
        job_executor = Kubernetes::JobExecutor.new(@output, job: @job)
        job_executor.execute!
      end

      ::JobExecution.start_job(job_execution)
    end
  end
end
