# frozen_string_literal: true
module SamsonDatadogTracer
  class Engine < Rails::Engine
  end

  class << self
    def enabled?
      !!ENV['DATADOG_TRACER']
    end

    def trace_execution_scoped(scope_name, &block)
      if enabled?
        Datadog.tracer.trace("Custom/Hooks/#{scope_name}", &block)
      else
        yield
      end
    end

    # We are not using super to make running newrelic (which uses alias) and datadog possible
    def trace_method(klass, method)
      visibility = method_visibility(klass, method)
      without = "without_apm_tracer_#{method}"
      if klass.method_defined?(without) || klass.private_method_defined?(without)
        raise "Tracer already defined for #{method}"
      end
      klass.alias_method without, method
      klass.define_method(method) do |*args, &block|
        Datadog.tracer.trace("#{klass}###{method}") do
          send(without, *args, &block)
        end
      end
      klass.send visibility, method
      klass.send visibility, without
    end

    private

    def method_visibility(klass, method)
      if klass.protected_method_defined?(method)
        :protected
      elsif klass.private_method_defined?(method)
        :private
      else
        :public
      end
    end
  end
end

require 'samson/performance_tracer'
Samson::PerformanceTracer.handlers << SamsonDatadogTracer

Samson::Hooks.callback :trace_method do |klass, method|
  if SamsonDatadogTracer.enabled?
    SamsonDatadogTracer.trace_method klass, method
  end
end

# TODO: support :asynchronous_performance_tracer hook, see lib/samson/performance_tracer.rb
