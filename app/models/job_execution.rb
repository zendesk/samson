require 'shellwords'

class JobExecution
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes.
  cattr_accessor(:enabled, instance_writer: false) do
    Rails.application.config.samson.enable_job_execution
  end

  cattr_accessor(:lock_timeout, instance_writer: false) { 10.minutes }
  cattr_accessor(:stop_timeout, instance_writer: false) { 15.seconds }

  cattr_reader(:registry, instance_accessor: false) { JobQueue.new }
  private_class_method :registry

  attr_reader :output, :reference, :job, :viewers, :executor

  delegate :id, to: :job

  def initialize(reference, job, env = {}, &block)
    @output = OutputBuffer.new
    @executor = TerminalExecutor.new(@output, verbose: true, project: job.project)
    @viewers = JobViewers.new(@output)

    @subscribers = []
    @env = env
    @job = job
    @reference = reference
    @execution_block = block

    @repository = @job.project.repository
    @repository.executor = @executor

    on_complete do
      @output.write('', :finished)
      @output.close

      @job.update_output!(OutputAggregator.new(@output).to_s)
    end
  end

  def start!
    ActiveRecord::Base.clear_active_connections!
    @thread = Thread.new { run! }
  end

  def wait!
    @thread.try(:join)
  end

  def pid
    @executor.pid
  end

  # Used on queued jobs when shutting down
  # so that the stream sockets are closed
  def close
    @output.write('', :reloaded)
    @output.close
  end

  def stop!
    if @thread
      @executor.stop! 'INT'

      stop_timeout.times do
        return if @thread.join(1)
      end

      @executor.stop! 'KILL'

      wait!
    else
      @job.cancelled!
      finish
    end
  end

  def on_complete(&block)
    @subscribers << JobExecutionSubscriber.new(job, block)
  end

  private

  def stage
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
      return @job.error! unless setup!(dir)

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
    finish
    ActiveRecord::Base.clear_active_connections!
  end
  add_transaction_tracer :run!, category: :task, params: '{ job_id: id, project: job.project.try(:name), reference: reference }'

  def finish
    @subscribers.each(&:call)
  end

  def execute!(dir)
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
      payload[:success] = if stage.try(:kubernetes)
        @executor = Kubernetes::DeployExecutor.new(@output, job: @job)
        @executor.execute!
      else
        @executor.execute!(*cmds)
      end
    end

    Samson::Hooks.fire(:after_job_execution, @job, payload[:success], @output)

    payload[:success]
  end

  def setup!(dir)
    locked = lock_project do
      return false unless @repository.setup!(dir, @reference)
      commit = @repository.commit_from_ref(@reference, length: 40)
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
      PROJECT_NAME: @job.project.name,
      PROJECT_PERMALINK: @job.project.permalink,
      PROJECT_REPOSITORY: @job.project.repository_url,
      REVISION: @reference,
      TAG: (@job.tag || @job.commit).to_s,
      CACHE_DIR: artifact_cache_dir
    }.merge(@env)

    env.merge!(Hash[*Samson::Hooks.fire(:job_additional_vars, @job)])

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
    callback = proc { |owner| @output.write("Waiting for repository while setting it up for #{owner}\n") if Time.now.to_i % 10 == 0 }
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

    def start_job(job_execution, key: job_execution.id)
      registry.add(key, job_execution)
    end

    def active
      registry.active
    end

    def clear_registry
      registry.clear
    end
  end
end
