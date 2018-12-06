# frozen_string_literal: true
# make jobs with the same queue run in serial and track their status
class JobQueue
  include Singleton

  STAGGER_INTERVAL = Integer(ENV['JOB_STAGGER_INTERVAL'] || '0').seconds

  # NOTE: Inherit from Exception so no random catch-call code swallows it
  class Cancel < Exception # rubocop:disable Lint/InheritException
  end

  # Whether or not execution is enabled. This allows completely disabling job
  # execution for testing purposes and when restarting samson.
  class << self
    attr_accessor :enabled
  end

  class << self
    delegate :executing, :executing?, :queued?, :dequeue, :find_by_id, :perform_later, :debug, :clear, :wait, :kill,
      :cancel, to: :instance
  end

  def executing
    @executing.values
  end

  def executing?(id)
    executing.detect { |je| je.id == id }
  end

  def queued?(id)
    (@queue + @stagger_queue).detect { |i| return i[:job_execution] if i[:job_execution].id == id }
  end

  def dequeue(id)
    !!@queue.reject! { |i| i[:job_execution].id == id }
  end

  def find_by_id(id)
    @lock.synchronize { executing?(id) || queued?(id) }
  end

  # when no queue is given jobs run in parallel (each in their own queue) and start instantly
  # when samson is restarting we do not start jobs, but leave them pending
  def perform_later(job_execution, queue: nil)
    queue ||= job_execution.id

    if JobQueue.enabled
      @lock.synchronize do
        if full?(queue)
          @queue.push(queue: queue, job_execution: job_execution)
          false
        else
          stagger_job_or_execute(job_execution, queue)
          true
        end
      end
    end

    instrument
  end

  def debug
    grouped = debug_hash_from_queue(@queue)

    result = [@executing, grouped]
    result << debug_hash_from_queue(@stagger_queue) if staggering_enabled?
    result
  end

  def clear
    raise unless Rails.env.test?
    @threads.each_value do |t|
      t.raise("Killed by JobQueue") if t.alive?
      sleep 0.05 while t.alive? # wait till it's done handling the exception
    end
    @threads.clear
    @executing.clear
    @queue.clear
    @stagger_queue.clear
  end

  def wait(id, timeout = nil)
    @threads[id]&.join(timeout)
  end

  def cancel(id)
    return unless thread = @threads[id]
    thread.raise(Cancel)
    thread.join # wait so after redirect user can see job output which is written in `ensure`
  end

  private

  def initialize
    @queue = []
    @stagger_queue = []
    @lock = Mutex.new
    @executing = {}
    @threads = {}

    if staggering_enabled?
      start_staggered_job_dequeuer
    end
  end

  # assign the thread first so we do not get into a state where the execution is findable but has no thread
  # so our mutex guarantees that all jobs/queues are in a valid state
  # ideally the job_execution should not know about it's thread and we would call cancel/wait on the job-queue instead
  def perform_job(job_execution, queue)
    @executing[queue] = job_execution

    @threads[job_execution.id] = Thread.new do
      begin
        ActiveRecord::Base.connection_pool.with_connection do
          begin
            job_execution.perform
          rescue Cancel
            # throw away the connection since it might be in a bad state
            # except in test, where all threads uses the same connection
            # TODO: tests have to reopen the connection if it went bad, but cannot do that without breaking transaction
            ActiveRecord::Base.connection.close unless Rails.env.test?
          end
        end
      ensure
        delete_and_enqueue_next(job_execution, queue)
        @threads.delete(job_execution.id)
      end
    end
  end

  def stagger_job_or_execute(job_execution, queue)
    if staggering_enabled?
      @stagger_queue.push(job_execution: job_execution, queue: queue)
    else
      perform_job(job_execution, queue)
    end
  end

  def dequeue_staggered_job
    @lock.synchronize do
      perform_job(*@stagger_queue.shift.values) unless @stagger_queue.empty?
    end
  end

  def start_staggered_job_dequeuer
    Concurrent::TimerTask.new(now: true, timeout_interval: 10, execution_interval: stagger_interval) do
      dequeue_staggered_job
    end.execute
  end

  def debug_hash_from_queue(queue)
    queue.each_with_object(Hash.new { |h, q| h[q] = [] }) do |queue_hash, h|
      h[queue_hash[:queue]] << queue_hash[:job_execution]
    end
  end

  def staggering_enabled?
    ENV['SERVER_MODE'] && stagger_interval != 0
  end

  def stagger_interval
    STAGGER_INTERVAL
  end

  def full?(queue)
    return true if @executing[queue]

    return false if concurrency == 0

    executing.length >= concurrency
  end

  def concurrency
    ENV['MAX_CONCURRENT_JOBS'].to_i
  end

  def delete_and_enqueue_next(job_execution, queue)
    @lock.synchronize do
      previous = @executing.delete(queue)
      unless job_execution == previous
        raise "Unexpected executing job found in queue #{queue}: expected #{job_execution&.id} got #{previous&.id}"
      end

      if JobQueue.enabled
        @queue.each do |i|
          if @executing[i[:queue]]
            next
          end
          @queue.delete(i)
          stagger_job_or_execute(i[:job_execution], i[:queue])
          break
        end
      end
    end

    instrument
  end

  def instrument
    ActiveSupport::Notifications.instrument(
      "job_queue.samson",
      jobs: {
        executing: @executing.length,
        queued: @queue.length,
      },
      deploys: {
        executing: @executing.values.select { |je| deploy? je }.size,
        queued: @queue.select { |i| deploy? i[:job_execution] }.size
      }
    )
  end

  def deploy?(job_execution)
    job_execution.respond_to?(:job) && job_execution.job.deploy
  end
end
