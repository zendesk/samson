# frozen_string_literal: true
module Samson
  module PerformanceTracer
    class << self
      # NOTE: this cannot be a hook since it is used from Hooks#fire
      def handlers
        @handlers ||= []
      end

      def trace_execution_scoped(scope_name, &block)
        # TODO: recheck Tracing the scope is restricted to avoid into slow startup
        # Refer Samson::BootCheck
        if ['staging', 'production'].include?(Rails.env)
          # TODO: caching this would be nice
          stack = handlers.inject(block) { |inner, plugin| plugin.trace_execution_scoped(scope_name) { inner } }
          stack.call
        else
          yield
        end
      end
    end

    module Tracers
      def add_tracer(method)
        Samson::Hooks.fire(:trace_method, self, method)
      end

      def add_asynchronous_tracer(method, options)
        Samson::Hooks.fire(:asynchronous_performance_tracer, self, method, options)
      end
    end
  end
end
