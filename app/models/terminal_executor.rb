require 'open3'

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

  def initialize(output, verbose: false, project: nil)
    @output = output
    @verbose = verbose
    @project = project
  end

  def execute!(*commands)
    if @verbose
      commands.map! { |c| "echo » #{c.shellescape}\n#{resolve_secrets(c)}" }
    else
      commands.map! { |c| resolve_secrets(c) }
    end
    commands.unshift("set -e")

    execute_command!(commands.join("\n"))
  end

  def stop!(signal)
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  private

  def resolve_secrets(command)
    allowed_namespaces = ['global']
    allowed_namespaces << @project.permalink if @project
    command.gsub(%r{\b#{SECRET_PREFIX}(#{SecretStorage::SECRET_KEY_REGEX})\b}) do
      key = $1
      if key.start_with?(*allowed_namespaces.map { |n| "#{n}/" })
        SecretStorage.read(key, include_secret: true).fetch(:value)
      else
        raise ActiveRecord::RecordNotFound, "Not allowed to access key #{key}"
      end
    end
  end

  def execute_command!(command)
    Open3.popen2e(whitelisted_env, command, in: '/dev/null', unsetenv_others: true, pgroup: true)  do |stdin, oe, wait_thr|
      @pid = wait_thr.pid

      @pgid = begin
        Process.getpgid(@pid)
      rescue Errno::ESRCH
        nil
      end

      oe.each(256) do |line|
        @output.write line.gsub("\n", "\r\n")
      end

      wait_thr.value
    end.success?
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
