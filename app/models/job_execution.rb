require 'thread_safe'
require 'terminal_executor'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_reader: true) { true }

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_reader: true)

  attr_reader :output

  def initialize(commit, job)
    @output = JobOutput.new
    @executor = TerminalExecutor.new
    @subscribers = []
    @job, @commit = job, commit

    @executor.output do |message|
      @output.push(message)
    end
  end

  def start!
    return unless enabled

    @thread = Thread.new do
      output_aggregator = OutputAggregator.new(@output)
      @job.run!

      begin
        dir = Dir.mktmpdir
        execute!(dir)
      ensure
        FileUtils.rm_rf(dir)
      end

      @output.close
      @job.update_output!(output_aggregator.to_s)

      ActiveRecord::Base.connection_pool.release_connection

      @subscribers.each do |subscriber|
        subscriber.call(@job)
      end
    end
  end

  def start_and_wait!
    start!
    wait!
  end

  def wait!
    @thread.try(:join)
  end

  def stop!
    @executor.stop!
    @thread.try(:join)
  end

  def subscribe(&block)
    @subscribers << block
  end

  private

  def execute!(dir)
    unless setup!(dir)
      @job.error!
      return
    end

    commands = [
      "export DEPLOYER=#{@job.user.email}",
      "export REVISION=#{@commit}",
      "cd #{dir}",
      *@job.commands
    ]

    if @executor.execute!(*commands)
      @job.success!
    else
      @job.fail!
    end
  end

  def setup!(dir)
    project = @job.project
    repo_url = project.repository_url
    repo_cache_dir = File.join(cached_repos_dir, project.id.to_s)

    commands = [
      <<-SHELL,
        if [ -d #{repo_cache_dir} ]
          then cd #{repo_cache_dir} && git fetch -ap
        else
          git clone --mirror #{repo_url} #{repo_cache_dir}
        fi
      SHELL
      "git clone #{repo_cache_dir} #{dir}",
      "cd #{dir}",
      "git checkout --quiet #{@commit}"
    ]

    @executor.execute!(*commands)
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
