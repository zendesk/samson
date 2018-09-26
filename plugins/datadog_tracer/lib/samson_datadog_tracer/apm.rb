# frozen_string_literal: true
module SamsonDatadogTracer
  module APM
    class << self
      def trace_method_execution_scope(scope_name)
        if SamsonDatadogTracer.enabled?
          Datadog.tracer.trace("Custom/Hooks/#{scope_name}") do
            yield
          end
        else
          yield
        end
      end

      # TODO: blow up when adding twice
      # We are not using super to make running newrelic (which uses alias) and datadog possible
      def trace_method(klass, method)
        visibility = method_visibility(klass, method)
        without = "without_apm_tracer_#{method}"
        klass.alias_method without, method
        klass.define_method(method) do |*args, &block|
          Datadog.tracer.trace("#{klass}###{method}") do
            send(without, *args, &block)
          end
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
end
