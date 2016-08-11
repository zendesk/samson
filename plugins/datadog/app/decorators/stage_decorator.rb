# frozen_string_literal: true
Stage.class_eval do
  def datadog_tags_as_array
    datadog_tags.to_s.split(";").map(&:strip)
  end

  def send_datadog_notifications?
    datadog_tags_as_array.any?
  end

  def datadog_monitors
    datadog_monitor_ids.to_s.split(/, ?/).map { |id| DatadogMonitor.new(id) }
  end
end
