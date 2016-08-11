# frozen_string_literal: true
require 'concurrent'

module Samson::Tasks
  class LockCleaner
    INTERVAL = 60

    # stop by calling .shutdown on the result
    def self.start
      new.send(:build).execute
    end

    private

    def build
      options = {run_now: true, execution_interval: INTERVAL, timeout_interval: 10}
      Concurrent::TimerTask.new(options) { run }.with_observer(self)
    end

    def run
      Lock.remove_expired_locks
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
