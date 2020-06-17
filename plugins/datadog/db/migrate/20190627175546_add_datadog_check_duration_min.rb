# frozen_string_literal: true
class AddDatadogCheckDurationMin < ActiveRecord::Migration[5.2]
  def change
    add_column :datadog_monitor_queries, :check_duration, :integer
  end
end
