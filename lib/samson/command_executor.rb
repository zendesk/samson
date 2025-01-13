# frozen_string_literal: true
require 'tempfile'

module Samson
  # safe command execution that makes sure to use timeouts for everything and cleans up dead sub processes
  module CommandExecutor
    class << self
      # timeout could be done more reliably with timeout(1) from gnu coreutils ... but that would add another dependency
      # popen vs timeout http://stackoverflow.com/questions/17237743/timeout-within-a-popen-works-but-popen-inside-a-timeout-doesnt
      # TODO: stream output so we have a partial output when command times out
      def execute(*command, timeout:, whitelist_env: [], env: {}, dir: nil)
        raise ArgumentError, "Positive timeout required" if timeout <= 0
        env = ENV.to_h.slice(*whitelist_env).merge(env)
        pio = nil
        stderr = Tempfile.new('stderr')
        popen_options = {unsetenv_others: true, err: stderr}
        popen_options[:chdir] = dir if dir

        ActiveSupport::Notifications.instrument("execute.command_executor.samson", script: command.shelljoin) do
          Timeout.timeout(timeout) do
            begin
              pio = IO.popen(env, command.map(&:to_s), popen_options)
              output = pio.read
              pio.close
              {
                output: output,
                error: File.read(stderr),
                status: $?.success?
              }
            rescue Errno::ENOENT
              {
                error: "No such file or directory - #{command.first}",
                status: false,
                output: ""
              }
            end
          end
        end
      rescue Timeout::Error
        {
          error: $!.message,
          status: false,
          output: ""
        }
      ensure
        if pio && !pio.closed?
          kill_process pio.pid
          pio.close
        end
      end

      private

      # timeout or parent process interrupted by user with Interrupt or SystemExit
      def kill_process(pid)
        Process.kill :INT, pid # tell it to stop
        sleep 1 # give it a second to clean up
        Process.kill :KILL, pid # kill it
        Process.wait pid # prevent zombie processes
      rescue Errno::ESRCH, Errno::ECHILD # kill or wait failing because pid was already gone
        nil
      end
    end
  end
end
