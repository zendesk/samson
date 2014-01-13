require 'thread_safe'
require 'executor/shell'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_reader: true) { true }

  attr_reader :output

  def initialize(commit, job, base_dir = Rails.root)
    @output = JobOutput.new
    @executor = Executor::Shell.new
    @subscribers = []
    @job, @commit, @base_dir = job, commit, base_dir

    @executor.output do |message|
      @output.push(message)
    end

    @executor.error_output do |message|
      @output.push(message)
    end
  end

  def start!
    return unless enabled

    @thread = Thread.new do
      output_aggregator = OutputAggregator.new(@output)
      @job.run!

      begin
        dir = File.join(Dir.tmpdir, "deploy-#{@job.id}")
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

    if @executor.execute!("cd #{dir}", *@job.commands)
      @job.success!
    else
      @job.fail!
    end
  end

  def setup!(dir)
    project = @job.project
    repo_url = project.repository_url
    cached_repos_dir = File.join(@base_dir, "cached_repos")
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
      "git checkout --quiet #{@commit}",
      "export DEPLOYER=#{@job.user.email}"
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
