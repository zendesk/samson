# frozen_string_literal: true
module Kubernetes
  module Api
    class HorizontalPodAutoscaler
      IGNORED_AUTOSCALE_EVENT_REASONS = [
        "FailedGetMetrics",
        "FailedRescale",
        "FailedGetResourceMetric",
        "FailedGetExternalMetric",
        "FailedComputeMetricsReplicas"
      ].freeze

      def events_indicating_failure(events)
        events.reject { |e| IGNORED_AUTOSCALE_EVENT_REASONS.include? e[:reason] }
      end
    end
  end
end
