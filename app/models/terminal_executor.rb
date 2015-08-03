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
  attr_reader :pid, :output

  def initialize(output, verbose: false)
    @output = output
    @verbose = verbose
  end

  def execute!(*commands)
    commands.map! { |c| "echo » #{c.shellescape}\n#{c}" } if @verbose
    commands.unshift("set -e")

    command = commands.join("\n")

    if RUBY_ENGINE == 'jruby'
      command = %Q{/bin/sh -c "#{command.gsub(/"/, '\\"')}"}
    end

    execute_command!(command)
  end

  def stop!(signal)
    # Need pkill because we want all
    # children of the parent process dead
    `pkill -#{signal} -P #{pid}` if pid
  end

  private

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
