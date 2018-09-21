# frozen_string_literal: true
module Samson
  module PerformanceTracer
    # It's used to trace the hook fire event,
    # We can't use the samson hook to fetch the available plugins.
    TRACER_PLUGINS = ['SamsonNewRelic', 'SamsonDatadogTracer::APM'].freeze

    class << self
      def included(clazz)
        clazz.extend ClassMethods
      end

      def trace_execution_scoped(scope_name)
        # Tracing the scope is restricted to avoid into slow startup
        # Refer Samson::BootCheck
        if ['staging', 'production'].include?(Rails.env)
          plugins = TRACER_PLUGINS.map(&:safe_constantize).compact
          execution = using_plugins plugins, scope_name do
            yield
          end
          execution.call
        else
          yield
        end
      end

      def using_plugins(plugins, scope_name, &block)
        plugins.inject(block) { |inner, plugin| plugin.trace_method_execution_scope(scope_name) { inner } }
      end
    end

    # Common class methods for Newrelic and Datadog.
    module ClassMethods
      def add_tracer(method)
        Samson::Hooks.fire(:performance_tracer, self, method)
      end

      # TODO: Add asynchronous tracer for Datadog.
      def add_asynchronous_tracer(method, options)
        Samson::Hooks.fire(:asynchronous_performance_tracer, self, method, options)
      end
    end
  end
end
