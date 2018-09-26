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

# TODO: turn this into a hook
Samson::PerformanceTracer.handlers << SamsonDatadogTracer::APM

Samson::Hooks.callback :performance_tracer do |klass, method|
  if SamsonDatadogTracer.enabled?
    SamsonDatadogTracer::APM.trace_method klass, method
  end
end
