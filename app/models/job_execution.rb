require 'shellwords'

class JobExecution
  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_writer: false) do
    Rails.application.config.samson.enable_job_execution
  end

  cattr_accessor(:lock_timeout, instance_writer: false) { 10.minutes }
  cattr_accessor(:stop_timeout, instance_writer: false) { 15.seconds }

  cattr_reader(:registry, instance_accessor: false) { JobQueue.new }
  private_class_method :registry

  attr_reader :output, :job, :viewers, :executor

  delegate :id, to: :job

  def initialize(reference, job, env = {}, &block)
    @output = OutputBuffer.new
    @executor = TerminalExecutor.new(@output, verbose: true)
    @viewers = JobViewers.new(@output)

    @subscribers = []
    @env = env
    @job = job
    @reference = reference
    @execution_block = block

    @repository = @job.project.repository
    @repository.executor = @executor

    on_complete do
      @output.close
      @job.update_output!(OutputAggregator.new(@output).to_s)
    end
  end

  def active?
    !!@thread
  end

  def start!
    ActiveRecord::Base.clear_active_connections!
    @thread = Thread.new { run! }
  end

  def wait!
    @thread.join if active?
  end

  # Used on queued jobs when shutting down
  # so that the stream sockets are closed
  def close
    @output.write('', :reloaded)
    @output.close
  end

  def stop!
    return unless active?

    @executor.stop! 'INT'

    stop_timeout.times do
      return if @thread.join(1)
    end

    @executor.stop! 'KILL'

    wait!
  end

  def on_complete(&block)
    @subscribers << JobExecutionSubscriber.new(job, block)
  end

  private

  def stage
    # TODO -- this class should not know about stages
    @job.deploy.try(:stage)
  end

  def error!(exception)
    message = "JobExecution failed: #{exception.message}"

    if !exception.is_a?(Samson::Hooks::UserError)
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
    @output.write('', :started)

    @job.run!

    success = Dir.mktmpdir do |dir|
      if @execution_block
        @execution_block.call(self, dir)
      else
        execute!(dir)
      end
    end

    if success
      @job.success!
    else
      @job.fail!
    end
  rescue => e
    error!(e)
  ensure
    @subscribers.each(&:call)
    ActiveRecord::Base.clear_active_connections!
  end

  def execute!(dir)
    unless setup!(dir)
      return @job.error!
    end

    Samson::Hooks.fire(:after_deploy_setup, dir, @job, @output, @reference)

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

    Samson::Hooks.fire(:after_job_execution, @job, payload[:success], @output)

    payload[:success]
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
      @output.write("Could not get exclusive lock on repo.\n")

      false
    end
  end

  def commands(dir)
    env = {
      DEPLOY_URL: @job.full_url,
      DEPLOYER: @job.user.email,
      DEPLOYER_EMAIL: @job.user.email,
      DEPLOYER_NAME: @job.user.name,
      REVISION: @reference,
      TAG: (@job.tag || @job.commit).to_s,
      CACHE_DIR: artifact_cache_dir
    }.merge(@env)

    commands = env.map do |key, value|
      "export #{key}=#{value.shellescape}"
    end

    commands << "cd #{dir}"
    commands.concat(@job.commands)
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
      registry.find(id)
    end

    def active?(id, key: id)
      registry.active?(key, id)
    end

    def queued?(id, key: id)
      registry.queued?(key, id)
    end

    def start_job(reference, job, key: job.id, **options, &block)
      registry.add(key, reference, job, options, &block)
    end

    def active
      registry.active
    end

    def clear_registry
      registry.clear
    end
  end
end
