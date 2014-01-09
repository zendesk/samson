require_relative 'base'
require 'pty'

module Executor
  class Shell < Base
    attr_reader :pid

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
      stdout, out = PTY.open
      stderr, err = PTY.open

      @pid = Bundler.with_clean_env do
        Process.spawn(command, in: "/dev/null", out: out, err: err)
      end

      out_thread = setup_callbacks(stdout, :stdout)
      err_thread = setup_callbacks(stderr, :stderr)

      _, status = Process.wait2(@pid)

      out.close
      err.close

      out_thread.join
      err_thread.join

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

    def setup_callbacks(io, io_name)
      Thread.new do
        ActiveRecord::Base.connection_pool.release_connection

        begin
          io.each do |line|
            @callbacks[io_name].each {|callback| callback.call(line.chomp("\n")) }
          end
        rescue Errno::EIO
          # The IO has been closed.
        end
      end
    end
  end
end
