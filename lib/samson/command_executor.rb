# frozen_string_literal: true
module Samson
  # TODO: reuse in git_repo ?
  # safe command execution that makes sure to use timeouts for everything and cleans up dead sub processes
  module CommandExecutor
    class << self
      # timeout could be done more reliably with timeout(1) from gnu coreutils ... but that would add another dependency
      def execute(*command, timeout:, whitelist_env: [])
        raise ArgumentError, "Positive timeout required" if timeout <= 0
        output = "ABORTED"
        pid = nil

        wait = Thread.new do
          begin
            IO.popen(ENV.to_h.slice(*whitelist_env), command, unsetenv_others: true, err: [:child, :out]) do |io|
              pid = io.pid
              output = io.read
            end
            $?&.success? || false
          rescue Errno::ENOENT
            output = "No such file or directory - #{command.first}"
            false
          end
        end
        success = Timeout.timeout(timeout) { wait.value } # using timeout in a blocking thread never interrupts

        return success, output
      rescue Timeout::Error
        kill_process pid if pid
        return false, $!.message
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
