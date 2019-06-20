# frozen_string_literal: true
class DatadogMonitorQuery < ActiveRecord::Base
  belongs_to :stage, inverse_of: :datadog_monitor_queries
  validates :query, format: /\A\d+\z|\A[a-z:,\d_-]+\z/
  validate :validate_query_works, if: :query_changed?

  def monitors
    @monitors ||= begin
      if query.match? /\A\d+\z/
        [DatadogMonitor.new(query)]
      else
        DatadogMonitor.list(monitor_tags: query)
      end
    end
  end

  private

  def validate_query_works
    return if errors[:query].any? # do not add to the pile
    return if monitors.any? && monitors.all?(&:state) # tag search failed or the id search returned a bad monitor
    errors.add :query, "#{query} did not find monitors"
  end
end
