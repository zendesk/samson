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
      puts "Waiting for jobs: #{JobExecution.active.map(&:id)}"
      sleep(5)
    end

    JobExecution.clear_registry

    puts "Passing SIGUSR2 on."

    # Pass USR2 to the underlying server
    Process.kill('SIGUSR2', Process.pid)
  end
end
