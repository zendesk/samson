require 'thread_safe'
require 'executor/shell'

class JobExecution
  attr_reader :output

  def initialize(commit, job)
    @output = JobOutput.new
    @executor = Executor::Shell.new

    @executor.output do |message|
      @output.push(message)
    end

    @executor.error_output do |message|
      @output.push(message)
    end

    job.start!

    dir = "/tmp/deploy-#{job.id}"

    commands = [
      "cd ~/#{job.project.repo_name}",
      "git fetch -ap",
      "git clone . #{dir}",
      "cd #{dir}",
      "git checkout --quiet #{commit}",
      "bundle check || bundle install --deployment --local --without test",
      # "export SUDO_USER=#{job.user.email}", capsu-only? We need a user.
      job.command
    ]

    if @executor.execute!(*commands)
      job.success!
    else
      job.fail!
    end

    job.update_output!(@output.to_s)
  end

  def stop!
    @executor.stop!
  end

  class << self
    def setup
      Thread.main[:job_executions] = ThreadSafe::Hash.new
    end

    def find_by_job(job)
      find_by_id(job.id)
    end

    def find_by_id(id)
      registry[id.to_i]
    end

    def start_job(commit, job)
      Rails.logger.debug "Starting job #{job.id.inspect}"
      registry[job.id] = new(commit, job)
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
