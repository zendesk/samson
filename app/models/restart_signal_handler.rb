# frozen_string_literal: true
# JobQueue locks a mutex, hence the need for a separate SignalHandler thread
# Self-pipe is also best practice, since signal handlers can themselves be interrupted
class RestartSignalHandler
  LISTEN_SIGNAL = 'SIGUSR1'
  PASSED_SIGNAL = 'SIGUSR2'

  class << self
    alias_method :listen, :new
  end

  def initialize
    @read, @write = IO.pipe
    Thread.new { run }
    Signal.trap(LISTEN_SIGNAL) { signal_restart }
  end

  private

  def signal_restart
    @write.puts
  end

  def run
    wait_for_restart_signal

    output 'preparing restart'

    JobExecution.enabled = false # Disable new job execution
    wait_for_active_jobs_to_finish

    output "Passing #{PASSED_SIGNAL} on."
    Process.kill(PASSED_SIGNAL, Process.pid) # shut down underlying server
  rescue
    output "Failed #{$!.message} ... restart manually when all deploys have finished"
    Airbrake.notify_sync($!)
    raise
  end

  def wait_for_restart_signal
    IO.select([@read])
  end

  def wait_for_active_jobs_to_finish
    loop do
      # dup-ing to avoid racing with other threads
      active = JobExecution.active.dup
      locks = MultiLock.locks.dup
      break if active.empty? && locks.empty?

      info = {
        jobs: active.map do |job_exec|
          {
            job_id: job_exec.id,
            pid: job_exec.pid,
            pgid: job_exec.pgid,
            descriptor: job_exec.descriptor
          }
        end,
        locks: locks
      }

      output 'waiting for jobs to complete', info
      sleep 5
    end
  end

  def output(message, data = {})
    output = {
      timestamp: Time.now.to_s,
      message: "RestartSignalHandler: #{message}"
    }.merge(data).to_json

    Rails.logger.info(output)
  end
end
