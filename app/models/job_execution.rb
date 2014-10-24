require 'thread_safe'
require 'airbrake'
require 'shellwords'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_writer: false) do
    Rails.application.config.samson.enable_job_execution
  end

  # The directory in which repositories should be cached.
  cattr_accessor(:cached_repos_dir, instance_writer: false) do
    Rails.application.config.samson.cached_repos_dir
  end

  cattr_accessor(:lock_timeout, instance_writer: false) { 10.minutes }

  cattr_reader(:registry, instance_accessor: false) { {} }
  private_class_method :registry

  attr_reader :output, :job, :viewers, :stage

  def initialize(reference, job)
    @output = OutputBuffer.new
    @executor = TerminalExecutor.new(@output)
    @viewers = JobViewers.new(@output)
    @subscribers = []
    @job, @reference = job, reference
    @stage = @job.deploy.try(:stage)
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

  def error!(exception)
    message = "JobExecution failed: #{exception.message}"

    Airbrake.notify(exception,
      error_message: message,
      parameters: {
        job_id: @job.id
      }
    )

    @output.write(message + "\n")
    @job.error! if @job.active?
    kill_child_deploys
  end

  def run!
    @job.run!

    output_aggregator = OutputAggregator.new(@output)

    result = Dir.mktmpdir do |dir|
      execute!(dir)
    end

    if result
      @job.success!
    else
      @job.fail!
    end

    @output.close

    @job.update_output!(output_aggregator.to_s)

    @subscribers.each(&:call)
  end

  def execute!(dir)
    unless setup!(dir)
      @job.error!
      return
    end

    FileUtils.mkdir_p(artifact_cache_dir)
    @output.write("Executing deploy\n")

    env_vars = {
      "SAMSON_ROOT" => Rails.application.root,
      "DEPLOYER" => @job.user.email.shellescape,
      "DEPLOYER_EMAIL" => @job.user.email.shellescape,
      "DEPLOYER_NAME" => @job.user.name.shellescape,
      "REVISION" => @reference.shellescape,
      "CACHE_DIR" => artifact_cache_dir
    }

    commands = env_vars.map { |k, v| "export #{k}=\"#{v}\"" } + [
      "cd #{dir}",
      *@job.commands
    ]

    ActiveRecord::Base.clear_active_connections!

    payload = {
      stage: (stage.try(:name) || "none"),
      project: @job.project.name,
      command: commands.join("\n")
    }

    ActiveSupport::Notifications.instrument("execute_shell.samson", payload) do
      payload[:success] = @executor.execute!(*commands)
    end

    kill_child_deploys

    payload[:success]
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

    locked = lock_project do
      return false unless @executor.execute!(*commands)
      commit = commit_from_ref(repo_cache_dir, @reference)
      @job.update_commit!(commit)
    end

    if locked
      true
    else
      @output.write("Could not get exclusive lock on repo. Maybe another stage is being deployed.\n")
      false
    end
  end

  def commit_from_ref(repo_dir, ref)
    description = Dir.chdir(repo_dir) do
      IO.popen(["git", "describe", "--long", "--tags", "--all", ref]) do |io|
        io.read.strip
      end
    end

    description.split("-").last.sub(/^g/, "")
  end

  def kill_child_deploys
    if @job.deploy.try(:has_children?)
      @job.deploy.children.each do |deploy|
        deploy.cancel! unless deploy.finished?
      end
    end
  end

  def repo_cache_dir
    File.join(cached_repos_dir, @job.project.repository_directory)
  end

  def artifact_cache_dir
    File.join(repo_cache_dir, "artifacts")
  end

  def lock_project(&block)
    holder = (stage.try(:name) || @job.user.name)
    failed_to_lock = lambda do |owner|
      if Time.now.to_i % 10 == 0
        @output.write("Waiting for repository while cloning for: #{owner}\n")
      end
    end

    MultiLock.lock(@job.project_id, holder, timeout: lock_timeout, failed_to_lock: failed_to_lock, &block)
  end

  class << self
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
  end
end
