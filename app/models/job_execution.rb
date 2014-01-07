require 'thread_safe'
require 'executor/shell'

class JobExecution
  attr_reader :output

  def initialize(commit, job)
    @output = JobOutput.new
    @executor = Executor::Shell.new
    @job, @commit = job, commit

    @executor.output do |message|
      Rails.logger.debug(message)
      @output.push(message)
    end

    @executor.error_output do |message|
      Rails.logger.debug(message)
      @output.push(message)
    end
  end

  def start!
    @thread = Thread.new do
      @job.run!

      dir = "/tmp/deploy-#{@job.id}"
      project = @job.project
      repo_url = project.repository_url
      cached_repos_dir = File.join(Rails.root, "cached_repos")
      repo_cache_dir = File.join(cached_repos_dir, project.id.to_s)

      commands = [
        "mkdir -p #{cached_repos_dir}",
        "if [ -d #{repo_cache_dir} ]; then cd #{repo_cache_dir} && git fetch -ap; else git clone #{repo_url} #{repo_cache_dir}; fi",
        "git clone #{repo_cache_dir} #{dir}",
        "cd #{dir}",
        "git checkout --quiet #{@commit}",
        # "export SUDO_USER=#{job.user.email}", capsu-only? We need a user.
        *@job.commands
      ]

      # Cleanup
      # `rm -rf #{dir}`

      if @executor.execute!(*commands)
        @job.success!
      else
        @job.fail!
      end

      @job.update_output!(@output.to_s)
    end
  end

  def stop!
    @executor.stop!
    @thread.try(:join)
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
      registry[job.id] = new(commit, job).tap(&:start!)
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
