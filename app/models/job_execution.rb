require 'thread_safe'
require 'airbrake'

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
  attr_reader :job
  attr_reader :viewers

  def initialize(reference, job)
    @output = OutputBuffer.new
    @executor = TerminalExecutor.new(@output)
    @viewers = JobViewers.new(@output)
    @subscribers = []
    @job, @reference = job, reference
  end

  def start!
    @thread = Thread.new do
      begin
        run!
      rescue => e
        Airbrake.notify(e,
          error_message: "JobExecution failed: #{e.message}",
          parameters: {
            job_id: @job.id
          }
        )
      ensure
        ActiveRecord::Base.clear_active_connections!
        JobExecution.finished_job(@job)
      end
    end
  end

  def run!
    @job.run!

    output_aggregator = OutputAggregator.new(@output)

    result = Dir.mktmpdir do |dir|
      execute!(dir)
    end

    @output.close

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.verify!

      if result
        @job.success!
      else
        @job.fail!
      end

      @job.update_output!(output_aggregator.to_s)

      @subscribers.each do |subscriber|
        subscriber.call(@job)
      end
    end
  end

  def wait!
    @thread.try(:join)
  end

  def stop!
    @executor.stop!
    wait!
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
      "export DEPLOYER_EMAIL=#{@job.user.email}",
      "export DEPLOYER_NAME=\"#{@job.user.name}\"",
      "export REVISION=#{@reference}",
      "export CACHE_DIR=#{artifact_cache_dir}",
      "cd #{dir}",
      *@job.commands
    ]

    ActiveRecord::Base.clear_active_connections!
    @executor.execute!(*commands)
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
    @executor.execute!('echo "Attempting to lock repository..."')
    our_lock = grab_lock
    if our_lock
      @executor.execute!(*commands).tap do |status|
        if status
          commit = `cd #{repo_cache_dir} && git rev-parse #{@reference}`.chomp
          @job.update_commit!(commit)
        end
      end
      release_lock
    end
  else
    @executor.execute!('echo "Could not get exclusive lock on repo. Maybe another stage is being deployed."')
    return false
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @job.project_id.to_s)
  end

  def artifact_cache_dir
    File.join(repo_cache_dir, "artifacts")
  end

  def grab_lock
    start_time = Time::now
    i = 0
    end_time = start_time + 10.minutes
    lock = :failure
    until (lock == :success || Time::now > end_time) do
      sleep 1
      i += 1
      i = i % 10
      if i == 0
        @executor.execute!('echo "Waiting for repository..."')
      end
      lock = @job.project.take_mutex!
    end
    if lock == :success
      true
    else
      false
    end
  end

  def release_lock
    @job.project.make_mutex!
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
      new(reference, job).tap do |job_execution|
        registry[job.id] = job_execution.tap(&:start!) if enabled
      end
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
