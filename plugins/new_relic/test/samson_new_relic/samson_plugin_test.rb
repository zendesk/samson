# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonNewRelic do
  describe :stage_permitted_params do
    it "lists extra keys" do
      found = Samson::Hooks.fire(:stage_permitted_params).detect do |x|
        x.is_a?(Hash) && x[:new_relic_applications_attributes]
      end
      assert found
    end
  end

  describe :stage_clone do
    let(:stage) { stages(:test_staging) }

    it "copies over the new relic applications" do
      stage.new_relic_applications = [NewRelicApplication.new(name: "test", stage_id: stage.id)]
      clone = Stage.build_clone(stage)
      attributes = [stage, clone].map { |s| s.new_relic_applications.map { |n| n.attributes.except("stage_id", "id") } }
      attributes[0].must_equal attributes[1]
    end
  end

  describe ".enabled?" do
    it "is disabled when KEY was not set" do
      refute SamsonNewRelic.enabled?
    end

    describe "when enabled" do
      with_new_relic_plugin_enabled

      it "is enabled when KEY was set" do
        assert SamsonNewRelic.enabled?
      end
    end
  end

  describe ".tracer_enabled?" do
    it "is disabled when env was not set" do
      refute SamsonNewRelic.tracer_enabled?
    end

    it "is enabled when env was set" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        assert SamsonNewRelic.tracer_enabled?
      end
    end
  end

  describe ".trace_method_execution_scope" do
    it "skips method trace when tracer disabled" do
      NewRelic::Agent::MethodTracerHelpers.expects(:trace_execution_scoped).never
      SamsonNewRelic.trace_method_execution_scope("test") { "without tracer" }
    end

    it "trace execution scope when enabled" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        NewRelic::Agent::MethodTracerHelpers.expects(:trace_execution_scoped)
        SamsonNewRelic.trace_method_execution_scope("test") { "with tracer" }
      end
    end
  end

  class Klass
    include ::Samson::PerformanceTracer
    def with_role
    end
    add_method_tracers :with_role
  end

  describe "#performance_tracer" do
    it "triggers method tracer when enabled" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        Klass.expects(:add_method_tracer)
        Samson::Hooks.fire :performance_tracer, Klass, [:with_role]
      end
    end

    it "skips method tracer when disabled" do
      with_env NEW_RELIC_LICENSE_KEY: nil do
        Klass.expects(:add_method_tracer).never
        Samson::Hooks.fire :performance_tracer, Klass, [:with_role]
      end
    end
  end

  describe "#asynchronous_performance_tracer" do
    it "triggers asynchronous tracer when enabled" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        Klass.expects(:add_transaction_tracer)
        Samson::Hooks.fire :asynchronous_performance_tracer, Klass, [:with_role]
      end
    end

    it "skips asynchronous tracer when disabled" do
      with_env NEW_RELIC_LICENSE_KEY: nil do
        Klass.expects(:add_transaction_tracer).never
        Samson::Hooks.fire :asynchronous_performance_tracer, Klass, [:with_role]
      end
    end
  end
end
