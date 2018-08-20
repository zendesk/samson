# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe SamsonDatadogTracer do
  describe ".enabled?" do
    before(:all) do
      ENV.delete('STATSD_TRACER')
    end
    context "in any environment" do
      it "is false by default" do
        refute SamsonDatadogTracer.enabled?
      end

      it "is true when STATSD_TRACER env var is set" do
        with_env STATSD_TRACER: "1" do
          assert SamsonDatadogTracer.enabled?
        end
        with_env STATSD_TRACER: nil do
          refute SamsonDatadogTracer.enabled?
        end
      end
    end
  end

  describe "#performance_tracer" do
    describe "when enabled" do
      it "triggers Datadog tracer method" do
        with_env STATSD_TRACER: "1" do
          class Klass
            include ::Samson::PerformanceTracer
            def with_role
            end
            add_method_tracers :with_role
          end
          Klass.expects(:trace_method)
          Samson::Hooks.fire :performance_tracer, Klass, [:with_role]
        end
      end
      it "skips tracer with missing method" do
        with_env STATSD_TRACER: "1" do
          helper = SamsonDatadogTracer::APM::Helpers
          method = :with_role
          Samson::Hooks.fire :performance_tracer, User, [method]
          refute User.method_defined?(helper.tracer_method_name(method))
        end
      end
    end

    it "skips Datadog tracer when disabled" do
      with_env STATSD_TRACER: nil do
        User.expects(:trace_method).never
        Samson::Hooks.fire :performance_tracer, User, [:with_role]
      end
    end
  end
end
