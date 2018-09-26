# frozen_string_literal: true
module SamsonDatadogTracer
  class Engine < Rails::Engine
  end

  def self.enabled?
    !!ENV['DATADOG_TRACER']
  end
end

require 'samson_datadog_tracer/apm'
require 'samson/performance_tracer'
Samson::PerformanceTracer.handlers << SamsonDatadogTracer::APM

Samson::Hooks.callback :performance_tracer do |klass, method|
  if SamsonDatadogTracer.enabled?
    klass.class_eval do
      include SamsonDatadogTracer::APM
      helper = SamsonDatadogTracer::APM::Helpers
      trace_method method
      alias_method helper.untracer_method_name(method), method
      alias_method method, helper.tracer_method_name(method)
    end
  end
end
