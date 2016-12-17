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

  def initialize(output, verbose: false, deploy: nil)
    @output = output
    @verbose = verbose
    @deploy = deploy
    @stopped = false
  end

  def execute!(*commands)
    return false if @stopped
    if @verbose
      commands.map! { |c| "echo » #{c.shellescape}\n#{resolve_secrets(c)}" }
    else
      commands.map! { |c| resolve_secrets(c) }
    end
    commands.unshift("set -e")

    execute_command!(commands.join("\n"))
  end

  def stop!(signal)
    @stopped = true
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  private

  def resolve_secrets(command)
    deploy_groups = @deploy.try(:stage).try(:deploy_groups) || []
    project = @deploy.try(:project)
    resolver = Samson::Secrets::KeyResolver.new(project, deploy_groups)

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

  def execute_command!(command)
    options = {in: '/dev/null', unsetenv_others: true}
    output, input, @pid = PTY.spawn(whitelisted_env, command, options)
    @pgid = pgid_from_pid(@pid)

    begin
      output.each(256) { |line| @output.write line }
    rescue Errno::EIO
      nil # output was closed ... only happens on linux
    end

    begin
      _pid, status = Process.wait2(@pid)
      status.success?
    rescue Errno::ECHILD
      @output.puts "#{$!.class}: #{$!.message}"
      false
    ensure
      input.close
    end
  end

  # We need the group pid to cleanly shut down all children
  # if we somehow fail to get that, kill everything now before more bad stuff happens
  def pgid_from_pid(pid)
    Process.getpgid(pid)
  rescue Errno::ESRCH
    @output.write "Failed to get pgid, stopping #{pid}."
    begin
      Process.kill(:KILL, pid)
      @output.write "Stopped."
    rescue Errno::ESRCH
      @output.write "Already stopped."
    end
    nil
  end

  def whitelisted_env
    whitelist = [
      'PATH', 'HOME', 'TMPDIR', 'CACHE_DIR', 'TERM', 'SHELL', # general
      'RBENV_ROOT', 'RBENV_HOOK_PATH', 'RBENV_DIR', # ruby
      'DOCKER_URL', 'DOCKER_REGISTRY' # docker
    ] + ENV['ENV_WHITELIST'].to_s.split(/, ?/)
    ENV.to_h.slice(*whitelist)
  end
end
