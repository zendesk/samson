# frozen_string_literal: true
module AcceptsDatadogMonitorQueries
  def self.included(base)
    base.class_eval do
      has_many :datadog_monitor_queries, dependent: :destroy, as: :scope
      accepts_nested_attributes_for :datadog_monitor_queries, allow_destroy: true, reject_if: ->(a) { a[:query].blank? }
    end
  end
end
