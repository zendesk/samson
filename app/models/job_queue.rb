class JobQueue
  LOCK = Mutex.new

  def initialize
    @queue = Hash.new {|h, k| h[k] = []}
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
    @queue.dup[key].any? {|je| je.id == id}
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

  def add(key, reference, job, on_complete: nil, **env, &block)
    job_execution = JobExecution.new(reference, job, env, &block)
    job_execution.on_complete(&on_complete) if on_complete
    job_execution.on_complete do
      pop(key)
    end

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

  def pop(key)
    LOCK.synchronize do
      job_execution = @active.delete(key)
      @registry.delete(job_execution.id) if job_execution

      if JobExecution.enabled && (job_execution = @queue[key].shift)
        @active[key] = job_execution
        job_execution.start!
      end
    end

    instrument
  end

  private

  def instrument
    ActiveSupport::Notifications.instrument "job.threads", thread_count: @active.length
  end
end
