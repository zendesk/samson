# frozen_string_literal: true
Stage.class_eval do
  has_many :datadog_monitor_queries, dependent: :destroy
  accepts_nested_attributes_for :datadog_monitor_queries, allow_destroy: true, reject_if: ->(a) { a[:query].blank? }

  def datadog_tags_as_array
    datadog_tags.to_s.split(";").map(&:strip!)
  end

  # also preloading the monitors in parallel for speed
  def datadog_monitors
    Samson::Parallelizer.map(datadog_monitor_queries) { |q| q.monitors.each(&:name) }.flatten(1)
  end
end
