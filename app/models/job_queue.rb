class JobQueue
  LOCK = Mutex.new

  def initialize
    @queue = Hash.new { |h, k| h[k] = [] }
    @active = {}
    @registry = {}
  end

  def active
    @active.values
  end

  def active?(key, id)
    @active[key].try(:id) == id
  end

  def queued?(key, id)
    @queue.dup[key].any? { |je| je.id == id }
  end

  # Assumes active threads will be closed by themselves
  def clear
    LOCK.synchronize do
      @queue.each do |_, jobs|
        jobs.each do |job|
          job.close
          @registry.delete(job.id)
        end
      end

      @queue.clear
    end
  end

  def find(id)
    @registry[id.to_i]
  end

  def add(key, job_execution)
    job_execution.on_complete { pop(key, job_execution) }

    LOCK.synchronize do
      @registry[job_execution.id] = job_execution

      if JobExecution.enabled
        if @active[key]
          @queue[key] << job_execution
        else
          @active[key] = job_execution
          job_execution.start!
        end
      end
    end

    instrument

    job_execution
  end

  def pop(key, job_execution)
    LOCK.synchronize do
      @registry.delete(job_execution.id)

      if @active[key] == job_execution
        @active.delete(key)

        if JobExecution.enabled && (job_execution = @queue[key].shift)
          @active[key] = job_execution
          job_execution.start!
        end
      else
        @queue[key].delete(job_execution)
      end
    end

    instrument
  end

  private

  def instrument
    ActiveSupport::Notifications.instrument "job.threads", thread_count: @active.length
  end
end
