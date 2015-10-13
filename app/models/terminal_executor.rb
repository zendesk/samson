require 'pty'
require 'shellwords'

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
    output, input = PTY.open
    @pid = spawn(command, unsetenv_others: true, out: input, in: '/dev/null')

    @pgid = begin
      Process.getpgid(pid)
    rescue Errno::ESRCH
      nil
    end

    begin
      output.each(56) {|line| @output.write(line) }
    rescue Errno::EIO
      # The IO has been closed.
    end

    _, status = Process.wait2(pid)

    input.close

    return status.success?
  end
end
