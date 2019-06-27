# frozen_string_literal: true
module Samson
  module PerformanceTracer
    class << self
      def trace_execution_scoped(scope, &block)
        tracers = Samson::Hooks.fire(:trace_scope, scope).compact
        tracers.inject(block) { |inner, tracer| -> { tracer.call(&inner) } }.call
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
