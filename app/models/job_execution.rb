require 'thread_safe'
require 'airbrake'
require 'shellwords'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_reader: true) do
    Rails.application.config.samson.enable_job_execution
  end

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_reader: true) do
    Rails.application.config.samson.cached_repos_dir
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
    ActiveRecord::Base.clear_active_connections!

    @thread = Thread.new do
      begin
        run!
      rescue => e
        error!(e)
      ensure
        @output.close unless @output.closed?
        ActiveRecord::Base.clear_active_connections!
        JobExecution.finished_job(@job)
      end
    end
  end

  def error!(exception, failed=true)
   message = "JobExecution #{ failed ? 'failed' : 'errored' }: #{exception.message}"

    Airbrake.notify(exception,
      error_message: message,
      parameters: {
        job_id: @job.id
      }
    )

    @output.write(message + "\n")
    @job.error! if failed && @job.active?
  end

  def run!
    @job.run!

    output_aggregator = OutputAggregator.new(@output)
    
    @output.add_write_callback do
      begin
        # we can't wait for the stream to complete
        oa = OutputAggregator.new(@output.to_a)
        @job.update_output!(oa.to_s)
      rescue Exception => e
        error!(e,false)
      end
    end

    result = Dir.mktmpdir do |dir|
      execute!(dir)
    end

    ActiveRecord::Base.connection.verify!

    if result
      @job.success!
    else
      @job.fail!
    end

    @output.close

    @job.update_output!(output_aggregator.to_s)

    @subscribers.each do |subscriber|
      subscriber.call(@job)
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
      if ProjectLock.owned?(@job.project)
        ProjectLock.release(@job.project)
      end

      @job.error!

      return
    end

    FileUtils.mkdir_p(artifact_cache_dir)
    @output.write("Executing deploy\n")

    commands = [
      "export DEPLOYER=#{@job.user.email.shellescape}",
      "export DEPLOYER_EMAIL=#{@job.user.email.shellescape}",
      "export DEPLOYER_NAME=#{@job.user.name.shellescape}",
      "export REVISION=#{@reference.shellescape}",
      "export CACHE_DIR=#{artifact_cache_dir}",
      "cd #{dir}",
      *@job.commands
    ]

    ActiveRecord::Base.clear_active_connections!

    payload = { stage: "none", project: "none", command: commands.join("\n")}

    unless @job.deploy.nil?
      payload[:stage] = @job.deploy.stage.name
      payload[:project] = @job.deploy.project.name
    end

    ActiveSupport::Notifications.instrument("execute_shell.samson", payload) do
      payload[:success] = @executor.execute!(*commands)
    end
  end

  def setup!(dir)
    repo_url = @job.project.repository_url.shellescape
    @output.write("Beginning git repo setup\n")

    commands = [
      <<-SHELL,
        if [ -d #{repo_cache_dir} ]
          then cd #{repo_cache_dir} && git fetch -ap
        else
          git -c core.askpass=true clone --mirror #{repo_url} #{repo_cache_dir}
        fi
      SHELL
      "git clone #{repo_cache_dir} #{dir}",
      "cd #{dir}",
      "git checkout --quiet #{@reference.shellescape}"
    ]

    @output.write("Attempting to lock repository...\n")

    if grab_lock
      @output.write("Repo locked, starting to clone...\n")

      @executor.execute!(*commands).tap do |status|
        if status
          commit = commit_from_ref(repo_cache_dir, @reference)
          ActiveRecord::Base.connection.verify!
          @job.update_commit!(commit)
          ProjectLock.release(@job.project)
        end
      end
    else
      @output.write("Could not get exclusive lock on repo. Maybe another stage is being deployed.\n")

      false
    end
  end

  def commit_from_ref(repo_dir, ref)
    description = Dir.chdir(repo_dir) do
      Tempfile.create("ref-description") do |file|
        system("git", "describe", "--long", "--tags", "--all", ref, out: file.fileno)
        file.rewind
        file.read.strip
      end
    end

    description.split("-").last.sub(/^g/, "")
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @job.project_id.to_s)
  end

  def artifact_cache_dir
    File.join(repo_cache_dir, "artifacts")
  end

  def grab_lock
    lock = false
    end_time = Time.now + 10.minutes
    holder = @job.deploy ? @job.deploy.stage.name : @job.user.name

    until lock || Time.now > end_time
      sleep 1

      if Time.now.to_i % 10 == 0
        @output.write("Waiting for repository while cloning for: #{ProjectLock.owner(@job.project)}\n")
      end

      lock ||= ProjectLock.grab(@job.project, holder)
    end

    lock
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
        if enabled
          registry[job.id] = job_execution.tap(&:start!)
          ActiveSupport::Notifications.instrument "job.threads", :thread_count => registry.length
        end
      end
    end

    def all
      registry.values
    end

    def finished_job(job)
      registry.delete(job.id)
      ActiveSupport::Notifications.instrument "job.threads", :thread_count => registry.length
    end

    private

    def registry
      Thread.main[:job_executions]
    end
  end
end
