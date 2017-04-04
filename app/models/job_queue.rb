# frozen_string_literal: true
# make jobs with the same queue run in serial and track their status
class JobQueue
  LOCK = Mutex.new

  def initialize
    @queue = Hash.new { |h, q| h[q] = [] }
    @active = {}
  end

  def active
    @active.values
  end

  def active?(id)
    active.detect { |je| je.id == id }
  end

  def queued?(id)
    @queue.values.detect { |jes| jes.detect { |je| return je if je.id == id } }
  end

  def dequeue(id)
    !!@queue.values.detect { |jes| jes.reject! { |je| je.id == id } }
  end

  def find_by_id(id)
    LOCK.synchronize { active?(id) || queued?(id) }
  end

  # Assumes active threads will be closed by themselves
  def clear
    LOCK.synchronize do
      @queue.each { |_, jes| jes.each(&:close) }
      @queue.clear
    end
  end

  # when no queue is given jobs run in parallel (each in their own queue) and start instantly
  # when samson is restarting we do not start jobs, but leave them pending
  def add(job_execution, queue: nil)
    queue ||= job_execution.id
    job_execution.on_complete { delete_and_enqueue_next(queue, job_execution) }

    LOCK.synchronize do
      if JobExecution.enabled
        if @active[queue]
          @queue[queue] << job_execution
        else
          start_job(job_execution, queue)
        end
      end
    end

    instrument

    job_execution
  end

  def debug
    [@active, @queue]
  end

  private

  def start_job(job_execution, queue)
    @active[queue] = job_execution
    job_execution.start!
  end

  def delete_and_enqueue_next(queue_name, job_execution)
    LOCK.synchronize do
      previous = @active.delete(queue_name)
      unless job_execution == previous
        raise "Unexpected active job found in queue #{queue_name}: expected #{job_execution&.id} got #{previous&.id}"
      end

      if JobExecution.enabled && (job_execution = @queue[queue_name].shift)
        start_job(job_execution, queue_name)
      end

      @queue.delete(queue_name) if @queue[queue_name].empty? # save memory, and time when iterating all queues
    end

    instrument
  end

  def instrument
    ActiveSupport::Notifications.instrument(
      "job_queue.samson",
      threads: @active.length,
      queued: @queue.values.sum(&:count)
    )
  end
end
