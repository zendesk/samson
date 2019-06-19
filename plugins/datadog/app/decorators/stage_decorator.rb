# frozen_string_literal: true
Stage.class_eval do
  def datadog_tags_as_array
    datadog_tags.to_s.split(";").map(&:strip!)
  end

  def datadog_monitors
    datadog_monitor_ids.to_s.split(/, ?/).grep(/\A\d+\z/).map { |id| DatadogMonitor.new(id) }
  end
end
