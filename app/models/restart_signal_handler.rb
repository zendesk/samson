# frozen_string_literal: true
# JobQueue locks a mutex, hence the need for a separate SignalHandler thread
# Self-pipe is also best practice, since signal handlers can themselves be interrupted
class RestartSignalHandler
  class << self
    alias_method :listen, :new
  end

  def initialize
    @read, @write = IO.pipe
    Thread.new { run }
    Signal.trap('SIGUSR1') { signal }
  end

  private

  def signal
    @write.puts
  end

  def run
    IO.select([@read])

    # Disable new job execution
    JobExecution.enabled = false

    until JobExecution.active.empty? && MultiLock.locks.empty?
      loginfo = {
        jobs: JobExecution.active.map do |job_exec|
          {
            job_id: job_exec.id,
            pid: job_exec.pid,
            pgid: job_exec.pgid,
            descriptor: job_exec.descriptor
          }
        end,
        locks: MultiLock.locks
      }

      output 'waiting for jobs to complete', loginfo
      sleep(5)
    end

    JobExecution.clear_queue

    output 'Passing SIGUSR2 on.'

    # Pass USR2 to the underlying server
    Process.kill('SIGUSR2', Process.pid)
  end

  def output(message, data = {})
    output = {
      timestamp: Time.now.to_s,
      message: message
    }.merge(data).to_json

    Rails.logger.info(output)
  end
end
