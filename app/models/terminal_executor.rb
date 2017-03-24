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

  attr_reader :pid, :pgid, :output

  def initialize(output, verbose: false, deploy: nil, project: nil)
    @output = output
    @verbose = verbose
    @deploy = deploy
    @project = project
    @stopped = false
  end

  def execute!(*commands)
    return false if @stopped
    options = {in: '/dev/null', unsetenv_others: true}
    output, input, pid = PTY.spawn(whitelisted_env, script(commands), options)
    record_pid(pid) do
      begin
        output.each(256) { |chunk| @output.write chunk }
      rescue Errno::EIO
        nil # output was closed ... only happens on linux
      end

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

  def stop!(signal)
    @stopped = true
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  private

  def script(commands)
    commands.map! do |c|
      if @verbose
        "echo » #{c.shellescape}\n#{resolve_secrets(c)}"
      else
        resolve_secrets(c)
      end
    end
    commands.unshift("set -e")
    commands.join("\n")
  end

  def resolve_secrets(command)
    deploy_groups = @deploy&.stage&.deploy_groups || []
    resolver = Samson::Secrets::KeyResolver.new(@project, deploy_groups)

    result = command.gsub(/\b#{SECRET_PREFIX}(#{SecretStorage::SECRET_KEY_REGEX})\b/) do
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
