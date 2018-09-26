# frozen_string_literal: true
module Samson
  module PerformanceTracer
    class << self
      # TODO: use a hook
      def handlers
        @handlers ||= []
      end

      def trace_execution_scoped(scope_name, &block)
        # TODO: recheck Tracing the scope is restricted to avoid into slow startup
        # Refer Samson::BootCheck
        if ['staging', 'production'].include?(Rails.env)
          using_plugins(handlers, scope_name, &block).call
        else
          yield
        end
      end

      private

      # TODO: rename this is weird
      def using_plugins(plugins, scope_name, &block)
        plugins.inject(block) { |inner, plugin| plugin.trace_method_execution_scope(scope_name) { inner } }
      end
    end

    module Tracers
      def add_tracer(method)
        Samson::Hooks.fire(:performance_tracer, self, method)
      end

      # TODO: Add asynchronous tracer support for Datadog.
      def add_asynchronous_tracer(method, options)
        Samson::Hooks.fire(:asynchronous_performance_tracer, self, method, options)
      end
    end
  end
end
