require 'thread_safe'
require 'terminal_executor'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_reader: true) do
    Rails.application.config.pusher.enable_job_execution
  end

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_reader: true) do
    Rails.application.config.pusher.cached_repos_dir
  end

  attr_reader :output

  def initialize(reference, job)
    @output = OutputBuffer.new
    @executor = TerminalExecutor.new(@output)
    @subscribers = []
    @job, @reference = job, reference
  end

  def start!
    return unless enabled

    @thread = Thread.new do
      ActiveRecord::Base.clear_active_connections!

      output_aggregator = OutputAggregator.new(@output)
      @job.run!

      Dir.mktmpdir do |dir|
        execute!(dir)
      end

      @output.close
      @job.update_output!(output_aggregator.to_s)

      @subscribers.each do |subscriber|
        subscriber.call(@job)
      end

      JobExecution.finished_job(@job)
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

    FileUtils.mkdir_p(artifact_cache_dir)

    commands = [
      "export DEPLOYER=#{@job.user.email}",
      "export REVISION=#{@reference}",
      "export CACHE_DIR=#{artifact_cache_dir}",
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
    repo_url = @job.project.repository_url

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
      "git checkout --quiet #{@reference}"
    ]

    @executor.execute!(*commands).tap do |status|
      if status
        commit = `cd #{repo_cache_dir} && git rev-parse #{@reference}`.chomp
        @job.update_commit!(commit)
      end
    end
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @job.project_id.to_s)
  end

  def artifact_cache_dir
    File.join(repo_cache_dir, "artifacts")
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

    def start_job(reference, job)
      registry[job.id] = new(reference, job).tap(&:start!)
    end

    def all
      registry.values
    end

    def finished_job(job)
      registry.delete(job.id)
    end

    private

    def registry
      Thread.main[:job_executions]
    end
  end
end
