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
  TIMEOUT = Integer(ENV["DEPLOY_TIMEOUT"] || 2.hours.to_i)

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

    script_as_file(script(commands)) do |file|
      options = {timeout: TIMEOUT, env: whitelisted_env, in: '/dev/null', pgroup: true}
      Samson::CommandExecutor.execute(*execute_as_tty(file), options) do |pio|
        record_pid(pio.pid) do
          pio.each(256) do |line|
            @output.write line.gsub(/\r?\n/, "\r\n") # script on travis returns \n and \r\n on osx and our servers
          end
        end
      end.first
    end
  end

  def stop!(signal)
    @stopped = true
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  private

  # http://stackoverflow.com/questions/1401002/trick-an-application-into-thinking-its-stdin-is-interactive-not-a-pipe
  def execute_as_tty(file)
    if RbConfig::CONFIG["target_os"].include?("darwin")
      ["script", "-q", "/dev/null", "sh", file]
    else
      ["script", "-qfec", "sh #{file}"]
    end
  end

  def script_as_file(script)
    Tempfile.open('samson-execute') do |f|
      f.write script
      f.flush
      yield f.path
    end
  end

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
