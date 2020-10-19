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

  describe ".find_api_key" do
    it "finds no key" do
      SamsonNewRelic.find_api_key.must_be_nil
    end

    it "finds new key" do
      with_env NEW_RELIC_API_KEY: 'foo' do
        SamsonNewRelic.find_api_key.must_equal 'foo'
      end
    end

    it "finds new key when old is set too (for easy transition)" do
      with_env NEW_RELIC_API_KEY: 'foo', NEWRELIC_API_KEY: 'foo' do
        SamsonNewRelic.find_api_key.must_equal 'foo'
      end
    end

    it "alerts when using only old key" do
      with_env NEWRELIC_API_KEY: 'foo' do
        e = assert_raises(RuntimeError) { SamsonNewRelic.find_api_key }
        e.message.must_equal "Use NEW_RELIC_API_KEY, not NEWRELIC_API_KEY"
      end
    end
  end

  describe ".setup_initializers" do
    it "loads basics in test mode" do
      SamsonNewRelic.setup_initializers
    end

    it "loads everything in staging" do
      Rails.expects(:env).returns('production')
      SamsonNewRelic.setup_initializers # no side-effects, but coverage will be 100%
    end
  end

  describe ".include_once" do
    it "includes once" do
      calls = 0
      a = Class.new
      b = Module.new do
        (class << self; self; end).define_method :included do |_|
          calls += 1
        end
      end
      SamsonNewRelic.include_once a, b
      SamsonNewRelic.include_once a, b
      calls.must_equal 1
    end
  end

  klass = Class.new do
    extend ::Samson::PerformanceTracer::Tracers
    def with_role
    end
    add_tracer :with_role
  end

  describe "#performance_tracer" do
    it "triggers method tracer when enabled" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        klass.expects(:add_method_tracer)
        Samson::Hooks.fire :trace_method, klass, [:with_role]
      end
    end

    it "skips method tracer when disabled" do
      with_env NEW_RELIC_LICENSE_KEY: nil do
        klass.expects(:add_method_tracer).never
        Samson::Hooks.fire :trace_method, klass, [:with_role]
      end
    end
  end

  describe "asynchronous_performance_tracer hook" do
    it "triggers asynchronous tracer when enabled" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        klass.expects(:add_transaction_tracer)
        Samson::Hooks.fire :asynchronous_performance_tracer, klass, [:with_role]
      end
    end

    it "skips asynchronous tracer when disabled" do
      with_env NEW_RELIC_LICENSE_KEY: nil do
        klass.expects(:add_transaction_tracer).never
        Samson::Hooks.fire :asynchronous_performance_tracer, klass, [:with_role]
      end
    end
  end

  describe ".trace_method_execution_scope" do
    it "skips method trace when tracer disabled" do
      NewRelic::Agent::MethodTracerHelpers.expects(:trace_execution_scoped).never
      Samson::PerformanceTracer.trace_execution_scoped(:foo) { 1 }.must_equal 1
    end

    it "trace execution scope when enabled" do
      with_env NEW_RELIC_LICENSE_KEY: "1" do
        NewRelic::Agent::MethodTracerHelpers.expects(:trace_execution_scoped).returns(2)
        Samson::PerformanceTracer.trace_execution_scoped(:foo) { 1 }.must_equal 2
      end
    end
  end
end
