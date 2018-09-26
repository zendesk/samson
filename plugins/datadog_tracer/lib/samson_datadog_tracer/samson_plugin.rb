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

Samson::Hooks.callback :trace_method do |klass, method|
  if SamsonDatadogTracer.enabled?
    SamsonDatadogTracer::APM.trace_method klass, method
  end
end

# TODO: support :asynchronous_performance_tracer hook, see lib/samson/performance_tracer.rb
