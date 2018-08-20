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

    describe '.add_method_tracers' do
      it 'add method tracer from performance_tracer hook' do
        methods = [:pub_method1, :pub_method2]
        performance_tracer_callback = lambda { |_, _| true }

        Samson::Hooks.with_callback(:performance_tracer, performance_tracer_callback) do
          assert TestKlass.add_method_tracers(methods)
        end
      end

      it 'raises with invalid arguments' do
        methods = [:pub_method1]
        performance_tracer_callback = lambda { |_| true }
        assert_raises ArgumentError do
          Samson::Hooks.with_callback(:performance_tracer, performance_tracer_callback) do
            assert TestKlass.add_method_tracers(methods)
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
