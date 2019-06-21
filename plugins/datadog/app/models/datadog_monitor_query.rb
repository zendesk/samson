# frozen_string_literal: true
class DatadogMonitorQuery < ActiveRecord::Base
  belongs_to :stage, inverse_of: :datadog_monitor_queries
  validates :query, format: /\A\d+\z/
  validate :validate_query_works, if: :query_changed?

  def monitors
    [DatadogMonitor.new(query)]
  end

  private

  def validate_query_works
    errors.add :query, "#{query} did not find a monitor" if errors[:query].empty? && DatadogMonitor.get(query).empty?
  end
end
