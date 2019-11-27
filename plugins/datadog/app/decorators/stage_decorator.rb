# frozen_string_literal: true
Stage.class_eval do
  include AcceptsDatadogMonitorQueries

  def datadog_tags_as_array
    datadog_tags.to_s.split(";").each(&:strip!)
  end

  private

  def all_datadog_monitor_queries
    project.datadog_monitor_queries + datadog_monitor_queries
  end
end
