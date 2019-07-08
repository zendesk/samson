# frozen_string_literal: true
# Inline Cron: use PERIODICAL environment variable
# Cron: Execute from commandline as cron via `rails runner 'Samson::Periodical.run_once :stop_expired_deploys'`
#
# Has global state so should never be autoloaded
require 'concurrent'

module Samson
  module Periodical
    TASK_DEFAULTS = {
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
        Samson::ErrorNotifier.notify(exception, error_message: "Samson::Periodical #{@task_name} failed")
      end
    end

    class << self
      attr_accessor :enabled

      def register(name, description, options = {}, &block)
        raise if options[:execution_interval]&.<= 0.01 # uncovered: avoid fishy code in concurrent around <=0.01
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

          # run at startup so we are in a consistent and clean state after a restart
          # not using TimerTask `now` option since then initial constant loading would happen in multiple threads
          # and we run into fun autoload errors like `LoadError: Unable to autoload constant Job` in development/test
          if !config[:now] && enabled
            ActiveRecord::Base.connection_pool.with_connection do
              run_once(name)
            end
          end

          with_consistent_start_time(config) do
            Concurrent::TimerTask.new(config) do
              track_running_count do
                if enabled
                  ActiveRecord::Base.connection_pool.with_connection { execute_block(config) }
                end
              end
            end.with_observer(ExceptionReporter.new(name)).execute
          end
        end.compact
      end

      # method to test things out on console / testing
      # simulates timeout that Concurrent::TimerTask does and exception reporting
      def run_once(name)
        config = registered.fetch(name)
        Timeout.timeout(config.fetch(:timeout_interval)) do
          execute_block(config)
        end
      rescue
        ExceptionReporter.new(name).update(nil, nil, $!)
      end

      def interval(name)
        config = registered.fetch(name)
        config.fetch(:active) && config.fetch(:execution_interval)
      end

      def running_task_count
        @running_tasks_count || 0
      end

      def next_execution_in(name)
        config = registered.fetch(name)
        raise unless config[:consistent_start_time] # otherwise we need to fetch the running tasks start time
        time_to_next_execution(config)
      end

      private

      def track_running_count
        @running_tasks_count ||= 0
        @running_tasks_count += 1
        yield
      ensure
        @running_tasks_count -= 1
      end

      def with_consistent_start_time(config, &block)
        if config[:consistent_start_time]
          Concurrent::ScheduledTask.execute(time_to_next_execution(config), &block)
        else
          yield
        end
      end

      def time_to_next_execution(config)
        execution_interval = config.fetch(:execution_interval)
        execution_interval - (Time.now.to_i % execution_interval)
      end

      def execute_block(config)
        config.fetch(:block).call # needs a Proc
      end

      def env_settings(name)
        @env_settings ||= configs_from_string(ENV['PERIODICAL'])
        @env_settings[name] || {}
      end

      def configs_from_string(string)
        string.to_s.split(/ ?, ?/).each_with_object({}) do |item, h|
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
