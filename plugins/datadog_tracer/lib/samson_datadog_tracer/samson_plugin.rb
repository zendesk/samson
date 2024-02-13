# frozen_string_literal: true
module SamsonDatadogTracer
  class SamsonPlugin < Rails::Engine
  end

  class << self
    def enabled?
      !!ENV['DATADOG_TRACER']
    end

    # We are not using super to make running newrelic (which uses alias) and datadog possible
    def trace_method(klass, method)
      wrap_method klass, method, "apm_tracer" do |&block|
        Datadog.tracer.trace("#{klass}###{method}", &block)
      end
    end

    private

    def wrap_method(klass, method, scope, &callback)
      visibility = method_visibility(klass, method)
      without = "without_#{scope}_#{method}"
      if klass.method_defined?(without) || klass.private_method_defined?(without)
        raise "#{scope} wrapper already defined for #{method}"
      end
      klass.alias_method without, method
      klass.define_method(method) do |*args, **kwargs, &block|
        callback.call { send(without, *args, **kwargs, &block) }
      end
      klass.send visibility, method
      klass.send visibility, without
    end

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

Samson::Hooks.callback :trace_scope do |scope|
  if SamsonDatadogTracer.enabled?
    ->(&block) { Datadog.tracer.trace("Custom/Hooks/#{scope}", &block) }
  end
end

Samson::Hooks.callback :trace_method do |klass, method|
  if SamsonDatadogTracer.enabled?
    SamsonDatadogTracer.trace_method klass, method
  end
end

# TODO: support :asynchronous_performance_tracer hook, see lib/samson/performance_tracer.rb
