# frozen_string_literal: true
#
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::PerformanceTracer do
  describe '#ClassMethods' do
    class TestKlass
      include Samson::PerformanceTracer

      def pub_method1
        :pub1
      end

      def pub_method2
        :pub2
      end
    end

    describe '.trace_execution_scoped' do
      it 'add tracer for scope' do
        Rails.stubs(:env).returns("staging")
        trace_scope = proc {}
        SamsonNewRelic.expects(:trace_method_execution_scope).returns(trace_scope)
        SamsonDatadogTracer::APM.expects(:trace_method_execution_scope).returns(trace_scope)
        Samson::PerformanceTracer.trace_execution_scoped('test_scope') { :scoped }
      end

      it 'skips scope tracing' do
        SamsonNewRelic.expects(:trace_method_execution_scope).never
        SamsonDatadogTracer::APM.expects(:trace_method_execution_scope).never
        Samson::PerformanceTracer.trace_execution_scoped('test_scope') { :scoped }.must_equal(:scoped)
      end
    end

    describe '.add_tracer' do
      it 'add method tracer from performance_tracer hook' do
        performance_tracer_callback = lambda { |_, _| true }
        Rails.stubs(:env).returns("staging")
        Samson::Hooks.with_callback(:performance_tracer, performance_tracer_callback) do
          assert TestKlass.add_tracer(:pub_method1)
          assert TestKlass.add_tracer(:pub_method2)
        end
      end

      it 'raises with invalid arguments' do
        performance_tracer_callback = lambda { |_| true }
        assert_raises ArgumentError do
          Samson::Hooks.with_callback(:performance_tracer, performance_tracer_callback) do
            assert TestKlass.add_tracer(:pub_method1)
          end
        end
      end
    end

    describe '.add_asynchronous_tracer' do
      it 'add asynchronous tracer from asynchronous_performance_tracer hook' do
        methods = [:pub_method1, :pub_method2]
        asyn_tracer_callback = lambda { |_, _, _| true }

        Samson::Hooks.with_callback(:asynchronous_performance_tracer, asyn_tracer_callback) do
          assert TestKlass.add_asynchronous_tracer(methods, {})
        end
      end

      it 'raises with invalid arguments' do
        methods = [:pub_method1]
        asyn_tracer_callback = lambda { |_, _| true }
        assert_raises ArgumentError do
          Samson::Hooks.with_callback(:asynchronous_performance_tracer, asyn_tracer_callback) do
            assert TestKlass.add_asynchronous_tracer(methods, {})
          end
        end
      end
    end
  end
end
