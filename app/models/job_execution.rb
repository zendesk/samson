# frozen_string_literal: true
require 'shellwords'

class JobExecution
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

  cattr_accessor(:cancel_timeout, instance_writer: false) { 15.seconds }

  attr_reader :output, :reference, :job, :executor

  delegate :id, to: :job
  delegate :pid, :pgid, to: :executor

  def initialize(reference, job, env: {}, output: OutputBuffer.new, &block)
    @output = output
    @executor = TerminalExecutor.new(@output, verbose: true, deploy: job.deploy, project: job.project)
    @start_callbacks = []
    @finish_callbacks = []
    @env = env
    @job = job
    @reference = reference
    @execution_block = block
    @cancelled = false
    @finished = false

    @repository = @job.project.repository
    @repository.executor = @executor

    on_start do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          JobOutputsChannel.stream @job, @output
        end
      end
    end

    on_finish do
      Rails.logger.info("Calling finish callback for Job Execution #{id}")
      # weird issue we are seeing with docker builds never finishing
      if !Rails.env.test? && !JobQueue.find_by_id(@job.id) && @job.active?
        ErrorNotifier.notify("Active but not running job found", job: @job.id)
        @output.write("Active but not running job found")
        @job.failed!
      end

      @output.write('', :finished)
      @output.close

      @job.update_output!(OutputAggregator.new(@output).to_s)
    end
  end

  def perform
    ActiveRecord::Base.connection_pool.with_connection { run }
  end

  # Used on queued jobs when shutting down
  # so that the stream sockets are closed
  def close
    @output.write('', :reloaded)
    @output.close
  end

  def cancel
    @cancelled = true
    @job.cancelling!
    build_finder.cancelled!
    @executor.cancel 'INT'
    unless JobQueue.wait(id, cancel_timeout)
      @executor.cancel 'KILL'
      JobQueue.wait(id, cancel_timeout) || JobQueue.kill(id)
    end
    @job.cancelled!
    finish
  end

  def on_start(&block)
    @start_callbacks << block
  end

  def on_finish(&block)
    @finish_callbacks << JobExecutionSubscriber.new(job, &block)
  end

  def descriptor
    "#{job.project.name} - #{reference}"
  end

  # also used for docker builds
  def base_commands(dir, env = {})
    artifact_cache_dir = File.join(@job.project.repository.repo_cache_dir, "artifacts")
    FileUtils.mkdir_p(artifact_cache_dir)

    env = {
      PROJECT_NAME: @job.project.name,
      PROJECT_PERMALINK: @job.project.permalink,
      PROJECT_REPOSITORY: @job.project.repository_url,
      CACHE_DIR: artifact_cache_dir
    }.merge(env)

    commands = env.map do |key, value|
      "export #{key}=#{value.to_s.shellescape}"
    end

    ["cd #{dir}"].concat commands
  end

  private

  def stage
    @job.deploy&.stage
  end

  def error!(exception)
    puts_if_present report_error(exception)
    puts_if_present "JobExecution failed: #{exception.message}"
    puts_if_present render_backtrace(exception)
    @job.errored! if @job.active?
  end

  def run
    @output.write('', :started)
    @start_callbacks.each(&:call)
    @job.running!

    success = make_tempdir do |dir|
      return @job.errored! unless setup(dir)

      if @execution_block
        @execution_block.call(self, dir)
      else
        execute(dir)
      end
    end

    if success
      @job.succeeded!
    else
      @job.failed!
    end

  # when thread was killed by 'cancel' it is in a bad state, avoid working
  rescue => e
    error!(e) unless @cancelled
  ensure
    finish unless @cancelled
  end
  add_transaction_tracer :run,
    category: :task,
    params: '{ job_id: id, project: job.project.try(:name), reference: reference }'

  def finish
    return if @finished
    @finished = true
    @finish_callbacks.each(&:call)
  end

  def execute(dir)
    Rails.logger.info("Executing Job Execution #{id}")
    Samson::Hooks.fire(:after_deploy_setup, dir, @job, @output, @reference)

    @output.write("\n# Executing deploy\n")
    @output.write("# Deploy URL: #{@job.deploy.url}\n") if @job.deploy

    cmds = commands(dir)
    payload = {
      stage: (stage&.name || "none"),
      project: @job.project.name,
      production: stage&.production?
    }

    ActiveSupport::Notifications.instrument("execute_job.samson", payload) do
      payload[:success] =
        if kubernetes?
          @executor = Kubernetes::DeployExecutor.new(@output, job: @job, reference: @reference)
          @executor.execute
        else
          @executor.execute(*cmds)
        end
    end

    Samson::Hooks.fire(:after_job_execution, @job, payload[:success], @output)

    payload[:success]
  end

  def kubernetes?
    defined?(SamsonKubernetes::Engine) && stage&.kubernetes
  end

  def setup(dir)
    Rails.logger.info("Setting up Job Execution #{id}")
    return unless resolve_ref_to_commit

    kubernetes? || @repository.checkout_workspace(dir, @reference)
  end

  def resolve_ref_to_commit
    commit = @repository.commit_from_ref(@reference)
    tag = @repository.fuzzy_tag_from_ref(@reference)
    if commit
      @job.update_git_references!(commit: commit, tag: tag)

      @output.puts("Commit: #{commit}")
      true
    else
      @output.puts("Could not find commit for #{@reference}")
      false
    end
  end

  def commands(dir)
    env = {
      DEPLOY_ID: @job.deploy&.id || @job.id,
      DEPLOY_URL: @job.url,
      DEPLOYER: @job.user.email,
      DEPLOYER_EMAIL: @job.user.email,
      DEPLOYER_NAME: @job.user.name,
      REFERENCE: @reference,
      REVISION: @job.commit,
      TAG: (@job.tag || @job.commit)
    }.merge(@env)

    env.merge!(make_builds_available) if stage&.builds_in_environment

    if deploy = @job.deploy
      env[:COMMIT_RANGE] = deploy.changeset.commit_range
    end

    env.merge!(Hash[*Samson::Hooks.fire(:job_additional_vars, @job).compact])

    base_commands(dir, env) + @job.commands
  end

  def make_builds_available
    # wait for builds to finish
    builds = build_finder.ensure_successful_builds

    # pre-download the necessary images in case they are not public
    ImageBuilder.local_docker_login do |login_commands|
      @executor.quiet do
        @executor.execute(
          *login_commands,
          *builds.map { |build| @executor.verbose_command("docker pull #{build.docker_repo_digest.shellescape}") }
        )
      end
    end

    # make repo-digests available to stage commands
    builds.map do |build|
      ["BUILD_FROM_#{build.dockerfile || build.image_name}", build.docker_repo_digest]
    end.to_h
  end

  # show full errors if we show exceptions
  def render_backtrace(exception)
    return unless Rails.application.config.consider_all_requests_local
    backtrace = Rails.backtrace_cleaner.filter(exception.backtrace).first(10)
    backtrace << '...'
    backtrace.join("\n")
  end

  def report_error(exception)
    return if exception.is_a?(Samson::Hooks::UserError) # do not spam us with users issues

    ErrorNotifier.notify(
      exception,
      error_message: exception.message,
      parameters: {job_id: @job.id},
      sync: true
    )
  end

  def puts_if_present(message)
    @output.puts message if message
  end

  def build_finder
    @build_finder ||= Samson::BuildFinder.new(@output, @job, @reference)
  end

  def make_tempdir
    result = nil
    Dir.mktmpdir("samson-#{@job.project.permalink}-#{@job.id}") do |dir|
      result = yield dir
    end
  rescue Errno::ENOTEMPTY, Errno::ENOENT
    ErrorNotifier.notify("Notify: make_tempdir error #{$!.message.split('@').first}")
    result # tempdir ensure sometimes fails ... not sure why ... return normally
  end
end
