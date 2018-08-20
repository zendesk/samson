# frozen_string_literal: true
module SamsonDatadogTracer
  class Engine < Rails::Engine
  end

  def self.enabled?
    !!ENV['STATSD_TRACER']
  end
end

Samson::Hooks.callback :performance_tracer do |klass, methods|
  if SamsonDatadogTracer.enabled?
    klass.is_a?(Class) && klass.class_eval do
      include SamsonDatadogTracer::APM

      helper = SamsonDatadogTracer::APM::Helpers
      methods.each do |method|
        trace_method method

        if method_defined?(method) || private_method_defined?(method)
          alias_method helper.untracer_method_name(method), method
          alias_method method, helper.tracer_method_name(method)
        end
      end
    end
  end
end
