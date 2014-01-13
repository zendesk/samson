require 'pty'

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

    ActiveSupport::Notifications.instrument("execute_shell.pusher", payload) do
      payload[:success] = execute_command!(command)
    end
  end

  def pid
    @pid
  end

  def stop!
    # Need pkill because we want all
    # children of the parent process dead
    `pkill -INT -P #{pid}` if pid
  end

  private

  def execute_command!(command)
    master, slave = PTY.open

    @pid = Bundler.with_clean_env do
      Process.spawn(command, in: "/dev/null", out: slave, err: slave)
    end

    io_thread = callback_thread(master)

    _, status = Process.wait2(@pid)

    slave.close
    io_thread.join

    return status.success?
  end

  def wrap_command(command)
    <<-G
#{command}
RETVAL=$?
if [ "$RETVAL" != "0" ];
then
echo '#{error(command)}' >&2
exit $RETVAL
fi
    G
  end

  def error(command)
    "Failed to execute \"#{command}\""
  end

  def callback_thread(io)
    Thread.new do
      ActiveRecord::Base.connection_pool.release_connection

      begin
        io.each(3) {|line| @output.write(line) }
      rescue Errno::EIO
        # The IO has been closed.
      end
    end
  end
end
