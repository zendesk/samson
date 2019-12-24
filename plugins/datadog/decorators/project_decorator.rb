# frozen_string_literal: true
Project.class_eval do
  include AcceptsDatadogMonitorQueries
  alias_method :all_datadog_monitor_queries, :datadog_monitor_queries
end
