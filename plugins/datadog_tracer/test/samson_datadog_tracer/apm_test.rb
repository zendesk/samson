# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe SamsonDatadogTracer::APM do
  module FakeTracer
    def self.trace(*)
      yield
    end
  end

  module Datadog
    def self.tracer
      FakeTracer
    end
  end

  describe ".trace_method_execution_scope" do
    it "skips tracer when disabled" do
      with_env DATADOG_TRACER: nil do
        Datadog.expects(:tracer).never
        SamsonDatadogTracer::APM.trace_method_execution_scope("test") { "without tracer" }
      end
    end

    it "trigger tracer when enabled" do
      with_env DATADOG_TRACER: "1" do
        Rails.stubs(:env).returns("staging")
        Datadog.expects(:tracer).returns(FakeTracer)
        SamsonDatadogTracer::APM.trace_method_execution_scope("test") { "with tracer" }
      end
    end
  end

  class TestKlass1
    include SamsonDatadogTracer::APM
    SamsonDatadogTracer::APM.module_eval { include Datadog }

    def pub_method
      :pub
    end

    trace_method :pub_method
  end

  describe "skips APM trace methods" do
    let(:klass) { TestKlass1.new }
    it "skips tracker when apm is not enabled" do
      Datadog.expects(:tracer).never
      klass.send(:pub_method)
    end
  end

  ENV.store("DATADOG_TRACER", "1")
  class TestKlass2
    include SamsonDatadogTracer::APM
    SamsonDatadogTracer::APM.module_eval { include Datadog }

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

    trace_method :pub_method
    trace_method :pri_method
    trace_method :pro_method
    trace_method :not_method
    alias_method :pub_method_with_apm_untracer, :pub_method
  end

  describe ".trace_method" do
    let(:apm) { TestKlass2.new }
    Datadog.expects(:tracer).returns(Datadog.tracer)

    it "wraps the private method in a trace call" do
      apm.send(:pri_method).must_equal(:pri)
    end

    it "wraps the public method in a trace call" do
      apm.send(:pub_method).must_equal(:pub)
    end

    it "raises with NoMethodError when undefined method call" do
      assert_raise NoMethodError do
        apm.send(:not_method)
      end
    end

    it "preserves method visibility" do
      assert apm.class.public_method_defined?(:pub_method)
      refute apm.class.public_method_defined?(:pri_method)
      assert apm.class.private_method_defined?(:pri_method)
    end
  end

  describe "#Alias methods" do
    let(:apm) { TestKlass2.new }
    it "defines alias methods for trace" do
      assert apm.class.method_defined?("pub_method_with_apm_tracer")
      assert apm.class.private_method_defined?("pri_method_with_apm_tracer")
    end

    it "defines alias methods for untrace" do
      assert apm.class.method_defined?("pub_method_with_apm_untracer")
      refute apm.class.private_method_defined?("pri_method_with_apm_untracer")
    end

    it "reponds to alias methods" do
      apm.send(:pub_method_with_apm_tracer).must_equal(:pub)
    end
  end

  describe "#Helpers" do
    it "returns sanitize name" do
      SamsonDatadogTracer::APM::Helpers.sanitize_name("Test@123").must_equal("test_123")
    end

    it "returns tracer method name" do
      SamsonDatadogTracer::APM::Helpers.tracer_method_name("test_method").must_equal("test_method_with_apm_tracer")
    end

    it "returns untracer method name" do
      SamsonDatadogTracer::APM::Helpers.untracer_method_name("test_method").must_equal("test_method_with_apm_untracer")
    end
  end
end
