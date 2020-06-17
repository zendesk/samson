# frozen_string_literal: true
class RemoveDeprecatedMonitorStageId < ActiveRecord::Migration[5.2]
  def change
    remove_column :datadog_monitor_queries, :stage_id
    add_index :datadog_monitor_queries, [:scope_id, :scope_type], length: {scope_type: 100}
  end
end
