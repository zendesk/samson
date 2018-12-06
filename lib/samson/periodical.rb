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
        puts "DEBUG:: NEW EXCEPTION REPORTER #{task_name}" if $debug_messages
        @task_name = task_name
      end

      def update(time, _result, exception)
        puts "DEBUG:: IN EXCEPTION REPORTER UPDATE #{exception.inspect}" if $debug_messages
        return unless exception
        puts "DEBUG:: HAS EXCEPTION #{exception.inspect}" if $debug_messages
        Rails.logger.error "(#{time})  with error #{exception}"
        puts "DEBUG:: BETWEEN LOGGING" if $debug_messages
        Rails.logger.error exception.backtrace.join("\n")
        puts "DEBUG:: ABOUT TO CALL NOTIFY WITH EXCEPTION #{exception.inspect} #{exception.message} #{exception.backtrace}" if $debug_messages
        ErrorNotifier.notify(exception, error_message: "Samson::Periodical #{@task_name} failed")
      rescue
        puts "DEBUG:: RESCUED IN UPDATE #{$!.inspect}" if $debug_messages
        raise $!
      end
    end

    class << self
      attr_accessor :enabled

      def register(name, description, options = {}, &block)
        puts "DEBBUG:: REGISTERED #{name}#{description}" if $debug_messages
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
        puts "DEBUG:: IN RUN" if $debug_messages
        registered.map do |name, config|
          puts "DEBUG:: ITERATING OVER #{name}" if $debug_messages
          next unless config.fetch(:active)
          puts "DEBUG:: IS ACTIVE" if $debug_messages
          # run at startup so we are in a consistent and clean state after a restart
          # not using TimerTask `now` option since then initial constant loading would happen in multiple threads
          # and we run into fun autoload errors like `LoadError: Unable to autoload constant Job` in development/test
          unless config[:now]
            ActiveRecord::Base.connection_pool.with_connection do
              puts "DEBUG:: RUNNING, NOT NOW #{name}" if $debug_messages
              run_once(name)
            end
          end

          with_consistent_start_time(config) do
            Concurrent::TimerTask.new(config) do
              puts "DEBUG:: RUNNING TIMER TASK FOR #{config}"
              track_running_count do
                puts "DEBUG:: IS IT ENABLED? #{enabled}" if $debug_messages
                if enabled
                  ActiveRecord::Base.connection_pool.with_connection { execute_block(config) }
                end
              end
            end.with_observer(ExceptionReporter.new(name)).execute
          end
        end.compact
      rescue
        puts "DEBUG:: RESCUED IN RUN #{$!.message}" if $debug_messages
        raise $!
      end

      # method to test things out on console / testing
      # simulates timeout that Concurrent::TimerTask does and exception reporting
      def run_once(name)
        puts "DEBUG:: IN RUN ONCE FOR #{name}" if $debug_messages
        config = registered.fetch(name)
        Timeout.timeout(config.fetch(:timeout_interval)) do
          puts "DEBUG:: IN TIMEOUT FOR #{name}" if $debug_messages
          execute_block(config)
        end
      rescue
        puts "DEBUG:: RESCUED #{name}" if $debug_messages
        ExceptionReporter.new(name).update(nil, nil, $!)
      end

      def interval(name)
        config = registered.fetch(name)
        config.fetch(:active) && config.fetch(:execution_interval)
      end

      def running_task_count
        @running_tasks_count || 0
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
          execution_interval = config.fetch(:execution_interval)
          time_to_next_execution = execution_interval - (Time.now.to_i % execution_interval)
          Concurrent::ScheduledTask.execute(time_to_next_execution, &block)
        else
          yield
        end
      end

      def execute_block(config)
        puts "DEBUG:: EXECUTING BLOCK FOR #{config}" if $debug_messages
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
