require 'thread_safe'
require 'executor/shell'

class JobExecution
  attr_reader :output

  def initialize(commit, job, base_dir = Rails.root)
    @output = JobOutput.new
    @executor = Executor::Shell.new
    @job, @commit, @base_dir = job, commit, base_dir

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
      ActiveRecord::Base.connection_pool.release_connection

      @job.run!

      dir = "/tmp/deploy-#{@job.id}"
      project = @job.project
      repo_url = project.repository_url
      cached_repos_dir = File.join(@base_dir, "cached_repos")
      repo_cache_dir = File.join(cached_repos_dir, project.id.to_s)

      commands = [
        "mkdir -p #{cached_repos_dir}",
        <<-SHELL,
          if [ -d #{repo_cache_dir} ]
            then cd #{repo_cache_dir} && git fetch -ap
          else
            git clone #{repo_url} #{repo_cache_dir}
          fi
        SHELL
        "cd #{repo_cache_dir}",
        "export REV=$(git rev-parse origin/#{@commit} || git rev-parse #{@commit})",
        "git clone . #{dir}",
        "cd #{dir}",
        "git checkout --quiet $REV",
        "export DEPLOYER=#{@job.user.email}",
        *@job.commands,
        "rm -fr #{dir}"
      ]

      if @executor.execute!(*commands)
        @job.success!
      else
        @job.fail!
      end

      @job.update_output!(@output.to_s)
    end
  end

  def start_and_wait!
    start!
    @thread.join
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
