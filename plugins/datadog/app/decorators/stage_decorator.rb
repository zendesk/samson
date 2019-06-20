# frozen_string_literal: true
Stage.class_eval do
  has_many :datadog_monitor_queries, dependent: :destroy
  accepts_nested_attributes_for :datadog_monitor_queries, allow_destroy: true, reject_if: ->(a) { a[:query].blank? }

  def datadog_tags_as_array
    datadog_tags.to_s.split(";").map(&:strip!)
  end

  def datadog_monitors
    datadog_monitor_queries.flat_map(&:monitors)
  end
end
