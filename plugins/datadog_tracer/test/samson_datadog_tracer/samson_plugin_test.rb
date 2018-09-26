# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe SamsonDatadogTracer do
  describe ".enabled?" do
    it "is false by default" do
      refute SamsonDatadogTracer.enabled?
    end

    it "is true when DATADOG_TRACER env var is set" do
      with_env DATADOG_TRACER: "1" do
        assert SamsonDatadogTracer.enabled?
      end
    end
  end

  describe "#performance_tracer" do
    it "triggers Datadog tracer method when enabled" do
      with_env DATADOG_TRACER: "1" do
        SamsonDatadogTracer::APM.expects(:trace_method)
        Samson::Hooks.fire :performance_tracer, User, :with_role
      end
    end

    it "skips Datadog tracer when disabled" do
      SamsonDatadogTracer::APM.expects(:trace_method).never
      Samson::Hooks.fire :performance_tracer, User, :with_role
    end
  end
end
