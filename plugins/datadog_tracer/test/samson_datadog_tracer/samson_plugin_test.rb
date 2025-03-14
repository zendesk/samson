# frozen_string_literal: true
require_relative "../test_helper"
require 'ddtrace'

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

  describe ".trace_method" do
    let(:instance) do
      Class.new do
        include SamsonDatadogTracer

        def pub_method
          :pub
        end

        protected

        def pro_method
          :pro
        end

        private

        def pri_method
          :pri
        end

        SamsonDatadogTracer.trace_method self, :pub_method
        SamsonDatadogTracer.trace_method self, :pri_method
        SamsonDatadogTracer.trace_method self, :pro_method
      end.new
    end

    it "wraps public method in a trace call" do
      Datadog::Tracing.expects(:trace).yields.returns(:pub)
      instance.send(:pub_method).must_equal(:pub)
    end

    it "wraps protected method in a trace call" do
      Datadog::Tracing.expects(:trace).yields.returns(:pro)
      instance.send(:pro_method).must_equal(:pro)
    end

    it "wraps private method in a trace call" do
      Datadog::Tracing.expects(:trace).yields.returns(:pri)
      instance.send(:pri_method).must_equal(:pri)
    end

    it "refuses to add the same wrapper twice since that would lead to infinite loops" do
      e = assert_raise RuntimeError do
        SamsonDatadogTracer.trace_method instance.class, :pub_method
      end
      e.message.must_include "apm_tracer wrapper already defined for pub_method"
    end

    [:pub_method, :pro_method, :pri_method].each do |method|
      it "refuses to add the same wrapper twice for #{method}" do
        e = assert_raise RuntimeError do
          SamsonDatadogTracer.trace_method instance.class, method
        end
        e.message.must_include "apm_tracer wrapper already defined for #{method}"
      end
    end

    it "fails with undefined method" do
      e = assert_raise NameError do
        SamsonDatadogTracer.trace_method instance.class, :no_method
      end
      e.message.must_include "undefined method `no_method'"
    end

    it "preserves method visibility" do
      instance.public_methods.must_include :pub_method
      instance.public_methods.wont_include :pri_method
      instance.protected_methods.must_include :pro_method
      instance.private_methods.must_include :pri_method
    end

    it "defines alias methods for without" do
      instance.public_methods.must_include :without_apm_tracer_pub_method
      instance.protected_methods.must_include :without_apm_tracer_pro_method
      instance.private_methods.must_include :without_apm_tracer_pri_method
    end
  end

  describe "trace_method hook" do
    it "triggers Datadog tracer method when enabled" do
      with_env DATADOG_TRACER: "1" do
        SamsonDatadogTracer.expects(:trace_method)
        Samson::Hooks.fire :trace_method, User, :foobar
      end
    end

    it "skips Datadog tracer when disabled" do
      SamsonDatadogTracer.expects(:trace_method).never
      Samson::Hooks.fire :trace_method, User, :foobar
    end
  end

  describe "trace_scope hook" do
    it "skips tracer when disabled" do
      Datadog::Tracing.expects(:trace).never
      Samson::PerformanceTracer.trace_execution_scoped(:foo) { 1 }.must_equal 1
    end

    it "trigger tracer when enabled" do
      with_env DATADOG_TRACER: "1" do
        Datadog::Tracing.expects(:trace).yields.returns(1)
        Samson::PerformanceTracer.trace_execution_scoped(:foo) { 1 }.must_equal 1
      end
    end
  end
end
