# frozen_string_literal: true
class AddRollbackToDatadogMonitors < ActiveRecord::Migration[5.2]
  def change
    add_column :datadog_monitor_queries, :rollback_on_alert, :boolean, null: false, default: false
  end
end
