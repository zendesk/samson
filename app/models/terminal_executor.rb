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
  attr_reader :pid

  def initialize(output)
    @output = output
  end

  def execute!(*commands)
    command = commands.map {|command| wrap_command(command) }.join("\n")

    if RUBY_ENGINE == 'jruby'
      command = %Q{/bin/sh -c "#{command.gsub(/"/, '\\"')}"}
    end

    payload = {}

    ActiveSupport::Notifications.instrument("execute_shell.samson", payload) do
      payload[:success] = execute_command!(command)
    end
  end

  def stop!
    # Need pkill because we want all
    # children of the parent process dead
    `pkill -INT -P #{pid}` if pid
  end

  private

  def execute_command!(command)
    output, input, @pid = Bundler.with_clean_env do
      PTY.spawn(command, in: "/dev/null")
    end

    begin
      output.each(3) {|line| @output.write(line) }
    rescue Errno::EIO
      # The IO has been closed.
    end

    _, status = Process.wait2(@pid)

    input.close

    return status.success?
  end

  def wrap_command(command)
    <<-G
#{command}
RETVAL=$?
if [ "$RETVAL" != "0" ];
then
echo #{error(command)} >&2
exit $RETVAL
fi
    G
  end

  def error(command)
    "Failed to execute \"#{command}\""
  end
end
