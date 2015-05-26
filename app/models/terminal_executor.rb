require 'pty'
require 'shellwords'

# Executes commands in a fake terminal. The output will be streamed to a
# specified IO-like object.
#
# Example:
#
#   output = StringIO.new
#   terminal = TerminalExecutor.new(output)
#   terminal.execute_command!("echo hello", "echo world")
#
#   output.string #=> "hello\r\nworld\r\n"
#
class TerminalExecutor
  attr_reader :pid, :output

  def initialize(output)
    @output = output
  end

  def stop!
    # Need pkill because we want all
    # children of the parent process dead
    `pkill -INT -P #{pid}` if pid
  end

  def execute_command!(command)
    output, input, @pid = Bundler.with_clean_env do
      PTY.spawn(command, in: "/dev/null")
    end

    begin
      output.each(56) {|line| @output.write(line) }
    rescue Errno::EIO
      # The IO has been closed.
    end

    _, status = Process.wait2(@pid)

    input.close

    return status.success?
  end
end
