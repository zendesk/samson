# frozen_string_literal: true
Stage.class_eval do
  include AcceptsDatadogMonitorQueries

  def datadog_tags_as_array
    datadog_tags.to_s.split(";").each(&:strip!)
  end

  # preloading the monitors in parallel for speed
  def datadog_monitors(with_failure_behavior: false)
    queries = project.datadog_monitor_queries + datadog_monitor_queries
    queries.select!(&:failure_behavior?) if with_failure_behavior # avoid loading unnecessary monitors
    Samson::Parallelizer.map(queries) { |q| q.monitors.each(&:name) }.flatten(1)
  end
end
