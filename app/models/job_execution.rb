require 'thread_safe'
require 'shellwords'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_writer: false) do
    Rails.application.config.samson.enable_job_execution
  end

  cattr_accessor(:lock_timeout, instance_writer: false) { 10.minutes }

  cattr_reader(:registry, instance_accessor: false) { {} }
  private_class_method :registry

  attr_reader :output, :job, :viewers, :stage

  def initialize(reference, job)
    @output = OutputBuffer.new
    @executor = TerminalExecutor.new(@output, verbose: true)
    @viewers = JobViewers.new(@output)
    @subscribers = []
    @job, @reference = job, reference
    @stage = @job.deploy.try(:stage)
    @repository = @job.project.repository
    @repository.executor = @executor
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

    if defined?(Airbrake)
      Airbrake.notify(exception,
        error_message: message,
        parameters: {
          job_id: @job.id
        }
      )
    end

    @output.write(message + "\n")
    @job.error! if @job.active?
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
    if setup!(dir)
      Samson::Hooks.fire(:after_deploy_setup, dir, stage) if stage
    else
      @job.error!
      return
    end

    FileUtils.mkdir_p(artifact_cache_dir)
    @output.write("\n# Executing deploy\n")
    @output.write("# Deploy URL: #{@job.deploy.url}\n") if @job.deploy

    cmds = commands(dir)
    payload = {
      stage: (stage.try(:name) || "none"),
      project: @job.project.name,
      command: cmds.join("\n")
    }

    ActiveRecord::Base.clear_active_connections!

    ActiveSupport::Notifications.instrument("execute_shell.samson", payload) do
      payload[:success] = @executor.execute!(*cmds)
    end
  end

  def setup!(dir)
    locked = lock_project do
      return false unless @repository.setup!(dir, @reference)
      commit = @repository.commit_from_ref(@reference)
      tag = @repository.tag_from_ref(@reference)
      @job.update_git_references!(commit: commit, tag: tag)
    end

    if locked
      true
    else
      @output.write("Could not get exclusive lock on repo. Maybe another stage is being deployed.\n")
      false
    end
  end

  def commands(dir)
    commands = [
      "export DEPLOY_URL=#{@job.full_url.shellescape}",
      "export DEPLOYER=#{@job.user.email.shellescape}",
      "export DEPLOYER_EMAIL=#{@job.user.email.shellescape}",
      "export DEPLOYER_NAME=#{@job.user.name.shellescape}",
      "export REVISION=#{@reference.shellescape}",
      "export TAG=#{(@job.tag || @job.commit).to_s.shellescape}",
      "export CACHE_DIR=#{artifact_cache_dir}",
      "cd #{dir}",
      *@job.commands
    ]
    if @stage && group_names = @stage.deploy_groups.pluck(:name).sort.map!(&:shellescape).join(" ")
      commands.unshift("export DEPLOY_GROUPS='#{group_names}'") if group_names.presence
    end
    commands
  end

  def artifact_cache_dir
    File.join(@repository.repo_cache_dir, "artifacts")
  end

  def lock_project(&block)
    holder = (stage.try(:name) || @job.user.name)
    callback = proc { |owner| output.write("Waiting for repository while setting it up for #{owner}\n") if Time.now.to_i % 10 == 0 }
    @job.project.with_lock(output: @output, holder: holder, error_callback: callback, timeout: lock_timeout, &block)
  end

  class << self
    def find_by_id(id)
      registry[id.to_i]
    end

    def start_job(reference, job)
      new(reference, job).tap do |job_execution|
        if enabled
          registry[job.id] = job_execution.tap(&:start!)
          ActiveSupport::Notifications.instrument "job.threads", thread_count: registry.length
        end
      end
    end

    def all
      registry.values
    end

    def finished_job(job)
      registry.delete(job.id)
      ActiveSupport::Notifications.instrument "job.threads", thread_count: registry.length
    end
  end
end
