# frozen_string_literal: true

# Temporary module to contain job staggering logic until it is no longer needed

module Samson
  module JobQueue
    module StaggerJobs
      STAGGER_INTERVAL = Integer(ENV['JOB_STAGGER_INTERVAL'] || '0').seconds

      def clear
        @stagger_queue.clear
        super
      end

      def queued?
        @stagger_queue.detect { |i| return i[:job_execution] if i[:job_execution].id == id } || super
      end

      def debug
        super << debug_hash_from_queue(@stagger_queue)
      end

      private

      def initialize
        @stagger_queue = []
        start_staggered_job_dequeuer if staggering_enabled?
        super
      end

      def handle_job(*args)
        if staggering_enabled?
          stagger_job_or_execute(*args)
        else
          super
        end
      end

      def stagger_job_or_execute(job_execution, queue)
        @stagger_queue.push(job_execution: job_execution, queue: queue)
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

      def staggering_enabled?
        ENV['SERVER_MODE'] && !stagger_interval.zero?
      end

      def stagger_interval
        STAGGER_INTERVAL
      end
    end
  end
end
