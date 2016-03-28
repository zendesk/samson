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
  attr_reader :pid, :pgid, :output

  def initialize(output, verbose: false)
    @output = output
    @verbose = verbose
  end

  def execute!(*commands)
    commands.map! { |c| "echo » #{c.shellescape}\n#{c}" } if @verbose
    commands.unshift("set -e")

    execute_command!(commands.join("\n"))
  end

  def stop!(signal)
    system('kill', "-#{signal}", "-#{pgid}") if pgid
  end

  private

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

