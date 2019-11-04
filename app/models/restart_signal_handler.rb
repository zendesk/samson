# frozen_string_literal: true
# Ensures that we wait for all jobs to finish before shutting down the process during restart.
# JobQueue locks a mutex, hence the need for a separate SignalHandler thread
# Self-pipe is also best practice, since signal handlers can themselves be interrupted

class RestartSignalHandler
  class << self
    alias_method :listen, :new

    def after_restart
      ActiveRecord::Base.connection_pool.with_connection do
        JobQueue.enabled = true

        # any job that was left running is dead now, so we can cancel it
        Job.running.each { |j| j.cancel(nil) }

        # start all non-deploys jobs waiting for restart
        Job.non_deploy.pending.each do |job|
          JobQueue.perform_later(JobExecution.new(job.commit, job))
        end

        # start all csv-exports jobs waiting for restart
        CsvExport.where(status: 'pending').find_each do |export|
          JobQueue.perform_later(CsvExportJob.new(export))
        end

        # start all ready deploy jobs waiting for restart
        Deploy.start_deploys_waiting_for_restart!
      end
    end
  end

  def initialize
    @read, @write = IO.pipe
    @puma_restart_handler = Signal.trap('SIGUSR1') { signal_restart }
    raise 'Wrong boot order, puma needs to be loaded first' unless @puma_restart_handler.is_a?(Proc)
    Thread.new { run }
  end

  private

  def signal_restart
    @write.puts
  end

  def run
    wait_for_restart_signal

    output 'Waiting for all Samson activity to stop'

    JobQueue.enabled = false # Disable new job execution
    Samson::Periodical.enabled = false
    wait_for_active_jobs_to_stop

    output "Calling puma restart handler"
    @puma_restart_handler.call
    sleep 5
    hard_restart
  rescue
    output "Failed #{$!.message} ... restart manually when all deploys have finished"
    Samson::ErrorNotifier.notify($!, sync: true)
    raise
  end

  # failsafe in case of puma restart failure, so process monitoring will hard restart Samson
  # this means that we lose all requests until Samson is booted up again. This is bad, but better
  # than hanging forever.
  def hard_restart
    Samson::ErrorNotifier.notify('Hard restarting, requests will be lost', sync: true)
    output 'Error: Sending SIGTERM to hard restart'
    Process.kill(:SIGTERM, Process.pid)
    sleep 5
    output 'Error: Sending SIGKILL to hard restart'
    Process.kill(:SIGKILL, Process.pid)
  end

  def wait_for_restart_signal
    IO.select([@read])
  end

  def wait_for_active_jobs_to_stop
    loop do
      # dup-ing to avoid racing with other threads
      executing = JobQueue.executing.dup
      locks = MultiLock.locks.dup
      running_task_count = Samson::Periodical.running_task_count

      break if executing.empty? && locks.empty? && running_task_count == 0

      info = {
        jobs: executing.map do |job_exec|
          {
            job_id: job_exec.id,
            pid: job_exec.pid,
            pgid: job_exec.pgid,
            descriptor: job_exec.descriptor
          }
        end,
        locks: locks,
        periodical: running_task_count
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
