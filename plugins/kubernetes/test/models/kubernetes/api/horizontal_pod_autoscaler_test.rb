# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Kubernetes::Api::HorizontalPodAutoscaler do
  let(:hpa) { Kubernetes::Api::HorizontalPodAutoscaler.new }

  describe "#events_indicating_failure" do
    let(:start_time) { "2017-03-31T22:56:20Z" }
    let(:event) { {metadata: {creationTimestamp: start_time}, kind: 'HorizontalPodAutoscaler', type: 'Warning'} }
    let(:events) { [event] }

    it "does not ignore bad events" do
      refute hpa.events_indicating_failure(events).empty?
    end

    it "ignores failing to get metrics" do
      event[:reason] = 'FailedGetMetrics'

      assert hpa.events_indicating_failure(events).empty?
    end

    it "ingores failures to scale" do
      event[:reason] = 'FailedRescale'

      assert hpa.events_indicating_failure(events).empty?
    end

    it "ignores failing to get resource metrics" do
      event[:reason] = 'FailedGetResourceMetric'

      assert hpa.events_indicating_failure(events).empty?
    end

    it "ignores failing to get external metrics" do
      event[:reason] = 'FailedGetExternalMetric'

      assert hpa.events_indicating_failure(events).empty?
    end

    it "ignores failing to compute metrics replicas" do
      event[:reason] = 'FailedComputeMetricsReplicas'

      assert hpa.events_indicating_failure(events).empty?
    end

    it "does not ignore an unknown HPA event" do
      event[:reason] = 'SomeOtherFailure'

      refute hpa.events_indicating_failure(events).empty?
    end
  end
end
