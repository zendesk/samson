# frozen_string_literal: true
module AcceptsDatadogMonitorQueries
  def self.included(base)
    base.class_eval do
      has_many :datadog_monitor_queries, dependent: :destroy, as: :scope
      accepts_nested_attributes_for :datadog_monitor_queries, allow_destroy: true, reject_if: ->(a) { a[:query].blank? }
    end
  end

  # check if there are monitors without triggering http requests
  def datadog_monitors?
    all_datadog_monitor_queries.any?
  end

  # preloading the monitors in parallel for speed
  # @return [Array<DatadogMonitor>]
  def datadog_monitors(with_failure_behavior: false)
    queries = all_datadog_monitor_queries
    queries.select!(&:failure_behavior?) if with_failure_behavior # avoid loading unnecessary monitors
    Samson::Parallelizer.map(queries) { |q| q.monitors.each(&:name) }.flatten(1)
  end
end
