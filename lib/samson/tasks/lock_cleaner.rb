require 'concurrent'

module Samson::Tasks
  class LockCleaner
    def self.start
      new.start
    end

    def start
      task.tap(&:execute)
    end

    def task
      @task ||= Concurrent::TimerTask.new(run_now: true, execution_interval: 60, timeout_interval: 10) do
        Lock.remove_expired_locks
      end.with_observer(self)
    end

    # called by Concurrent::TimerTask
    def update(time, _result, exception)
      if exception
        Rails.logger.error "(#{time})  with error #{exception}"
        Rails.logger.error exception.backtrace.join("\n")
        Airbrake.notify(exception, error_message: "Samson::Tasks::LockCleaner failed")
      end
    end
  end
end
