# frozen_string_literal: true
class AddScopingToDatadogMonitors < ActiveRecord::Migration[5.2]
  def change
    add_column :datadog_monitor_queries, :match_target, :string
    add_column :datadog_monitor_queries, :match_source, :string
  end
end
