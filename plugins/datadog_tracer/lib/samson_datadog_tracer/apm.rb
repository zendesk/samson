# frozen_string_literal: true
module SamsonDatadogTracer
  module APM
    class << self
      def included(clazz)
        clazz.extend ClassMethods
      end

      def trace_method_execution_scope(scope_name)
        if SamsonDatadogTracer.enabled?
          Datadog.tracer.trace("Custom/Hooks/#{scope_name}") do
            yield
          end
        else
          yield
        end
      end
    end

    module ClassMethods
      def trace_method(method)
        return unless SamsonDatadogTracer.enabled?
        # Wrap the helper methods and alias method into the module.
        # prepend the wraped module to base class
        @apm_module ||= begin
          mod = Module.new
          mod.extend(SamsonDatadogTracer::APM::Helpers)
          prepend(mod)
          mod
        end
        if method_defined?(method) || private_method_defined?(method)
          _add_wrapped_method_to_module(method)
        end

        @traced_methods ||= []
        @traced_methods << method
      end

      private

      def _add_wrapped_method_to_module(method)
        klass = self

        @apm_module.module_eval do
          _wrap_method(method, klass)
        end
      end
    end

    module Helpers
      class << self
        def sanitize_name(name)
          name.to_s.parameterize.tr('-', '_')
        end

        def tracer_method_name(method_name)
          "#{sanitize_name(method_name)}_with_apm_tracer"
        end

        def untracer_method_name(method_name)
          "#{sanitize_name(method_name)}_with_apm_untracer"
        end
      end

      private

      def _wrap_method(method, klass)
        visibility = _original_visibility(method, klass)
        _define_traced_method(method, "#{klass}##{method}")
        _set_visibility(method, visibility)
      end

      def _original_visibility(method, klass)
        if klass.protected_method_defined?(method)
          :protected
        elsif klass.private_method_defined?(method)
          :private
        else
          :public
        end
      end

      def _define_traced_method(method, trace_name)
        define_method(Helpers.tracer_method_name(method)) do |*args, &block|
          Datadog.tracer.trace(trace_name) do
            send(Helpers.untracer_method_name(method), *args, &block)
          end
        end
      end

      def _set_visibility(method, visibility)
        method_name = Helpers.tracer_method_name(method)
        case visibility
        when :protected
          protected(method_name)
        when :private
          private(method_name)
        else
          public(method_name)
        end
      end
    end
  end
end
