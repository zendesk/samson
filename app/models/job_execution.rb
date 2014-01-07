require 'thread_safe'

class JobExecution
  attr_reader :output

  def initialize
    @output = JobOutput.new
    @output.push("Hello, World!")
  end

  def stop!
  end

  class << self
    def setup
      Thread.main[:job_executions] = ThreadSafe::Hash.new
    end

    def find_by_job(job)
      find_by_id(job.id)
    end

    def find_by_id(id)
      registry.fetch(id.to_i)
    end

    def start_job(commit, job)
      Rails.logger.debug "Starting job #{job.id.inspect}"
      registry[job.id] = new
    end

    def all
      registry.values
    end

    private

    def registry
      Thread.main[:job_executions]
    end
  end
end
