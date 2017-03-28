# frozen_string_literal: true
# Inline Cron: use PERIODICAL environment variable
# Cron: Execute from commandline as cron via `rails runner 'Samson::Periodical.run_once :stop_expired_deploys'`
#
# Has global state so should never be autoloaded
require 'concurrent'

module Samson
  module Periodical
    TASK_DEFAULTS = {
      now: true, # see TimerTask, run at startup so we are in a consistent and clean state after a restart
      execution_interval: 60, # see TimerTask
      timeout_interval: 10, # see TimerTask
      active: false
    }.freeze

    class ExceptionReporter
      def initialize(task_name)
        @task_name = task_name
      end

      def update(time, _result, exception)
        return unless exception
        Rails.logger.error "(#{time})  with error #{exception}"
        Rails.logger.error exception.backtrace.join("\n")
        Airbrake.notify(exception, error_message: "Samson::Periodical #{@task_name} failed")
      end
    end

    class << self
      def register(name, description, options = {}, &block)
        registered[name] = TASK_DEFAULTS.
          merge(env_settings(name)).
          merge(block: block, description: description).
          merge(options)
      end

      # works with cron like setup for .run_once and in process execution via .run
      def overdue?(name, since)
        interval = registered.fetch(name).fetch(:execution_interval)
        since < (interval * 2).seconds.ago
      end

      def run
        registered.map do |name, config|
          next unless config.fetch(:active)
          Concurrent::TimerTask.new(config) { config.fetch(:block).call }. # needs a Proc
            with_observer(ExceptionReporter.new(name)).
            execute
        end.compact
      end

      def run_once(name)
        config = registered.fetch(name)
        Timeout.timeout(config.fetch(:timeout_interval)) do
          config.fetch(:block).call
        end
      rescue
        ExceptionReporter.new(name).update(nil, nil, $!)
        raise
      end

      private

      def env_settings(name)
        @env_settings ||= configs_from_string(ENV['PERIODICAL'])
        @env_settings[name] || {}
      end

      def configs_from_string(string)
        string.to_s.split(',').each_with_object({}) do |item, h|
          name, execution_interval = item.split(':', 2)
          config = {active: true}
          config[:execution_interval] = Integer(execution_interval) if execution_interval
          h[name.to_sym] = config
        end
      end

      def registered
        @registered ||= {}
      end
    end
  end
end
