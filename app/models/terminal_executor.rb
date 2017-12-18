# frozen_string_literal: true
require 'pty'

# Executes commands in a fake terminal. The output will be streamed to a
# specified IO-like object.
#
# Example:
#
#   output = StringIO.new
#   terminal = TerminalExecutor.new(output)
#   terminal.execute!("echo hello", "echo world")
#
#   output.string #=> "hello\r\nworld\r\n"
#
class TerminalExecutor
  SECRET_PREFIX = "secret://"

  attr_reader :pid, :pgid, :output, :timeout

  def initialize(output, verbose: false, deploy: nil, project: nil)
    @output = output
    @verbose = verbose
    @deploy = deploy
    @project = project
    @cancelled = false
    @timeout = Integer(ENV["DEPLOY_TIMEOUT"] || 2.hours.to_i)
  end

  def execute(*commands, timeout: @timeout)
    return false if @cancelled
    options = {in: '/dev/null', unsetenv_others: true}
    script_as_executable(script(commands)) do |command|
      output, input, pid = PTY.spawn(whitelisted_env, command, options)
      record_pid(pid) do
        timeout_execution(timeout) do
          stream from: output, to: @output

          begin
            _pid, status = Process.wait2(pid)
            status.success?
          rescue Errno::ECHILD
            @output.puts "#{$!.class}: #{$!.message}"
            false
          ensure
            input.close
          end
        end
      end
    end
  end

  def cancel(signal)
    @cancelled = true
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  # used when only selected commands should be shown to the user
  def verbose_command(c)
    raise "executor already shows all commands, maybe use `quiet` ?" if @verbose
    print_and_execute c, resolve: false
  end

  def quiet
    old = @verbose
    @verbose = false
    yield
  ensure
    @verbose = old
  end

  private

  # write script to a file so it cannot be seen via `ps`
  def script_as_executable(script)
    f = Tempfile.new "samson-terminal-executor"
    File.chmod(0o700, f.path) # making sure nobody can read it before we add content
    f.write script
    f.close
    command = f.path

    # osx has a 4s startup delay for each new executable, so we keep the executable stable
    if RbConfig::CONFIG['host_os'].include?('darwin')
      command = "export FILE=#{f.path.shellescape} && #{File.expand_path("bin/script-executor").shellescape}"
    end

    yield command
  ensure
    f.unlink
  end

  def timeout_execution(time, &block)
    Timeout.timeout(time, &block)
  rescue Timeout::Error
    cancel 'INT'
    @output.puts "Timeout: execution took longer then #{time}s and was terminated"
    false
  end

  def stream(from:, to:)
    from.each(256) do |chunk|
      chunk = chunk.gsub(/\r\e\[\d+[ABCD]\r\n/, "\r") # ignore cursor movement http://ascii-table.com/ansi-escape-sequences.php
      to.write chunk
    end
  rescue Errno::EIO
    nil # output was closed ... only happens on linux
  end

  def script(commands)
    commands.map! do |c|
      if @verbose
        print_and_execute(c)
      else
        resolve_secrets(c)
      end
    end
    commands.unshift("set -e")
    commands.join("\n")
  end

  def print_and_execute(c, resolve: true)
    "echo » #{c.shellescape}\n#{resolve ? resolve_secrets(c) : c}"
  end

  def resolve_secrets(command)
    return command unless command.include?(SECRET_PREFIX)
    deploy_groups = @deploy&.stage&.deploy_groups || []
    resolver = Samson::Secrets::KeyResolver.new(@project, deploy_groups)

    result = command.gsub(/\b#{SECRET_PREFIX}(#{SecretStorage::SECRET_ID_REGEX})\b/) do
      key = $1
      if expanded = resolver.expand('unused', key).first&.last
        key.replace(expanded)
        SecretStorage.read(key, include_value: true).fetch(:value)
      end
    end

    resolver.verify!

    result
  end

  # reset pid after a command has finished so we do not kill random pids
  def record_pid(pid)
    @pid = pid
    @pgid = pgid_from_pid(pid)
    yield
  ensure
    @pid = nil
    @pgid = nil
  end

  # We need the group pid to cleanly shut down all children
  # if we fail to get that, the process is already dead (finished quickly or crashed)
  def pgid_from_pid(pid)
    Process.getpgid(pid)
  rescue Errno::ESRCH
    nil
  end

  def whitelisted_env
    whitelist = [
      'PATH', 'HOME', 'TMPDIR', 'CACHE_DIR', 'TERM', 'SHELL', # general
      'RBENV_ROOT', 'RBENV_HOOK_PATH', 'RBENV_DIR', # ruby
      'DOCKER_HOST', 'DOCKER_URL', 'DOCKER_REGISTRY' # docker
    ] + ENV['ENV_WHITELIST'].to_s.split(/, ?/)
    env = ENV.to_h.slice(*whitelist)
    env['DOCKER_REGISTRY'] ||= DockerRegistry.first&.host # backwards compatibility
    env
  end
end
