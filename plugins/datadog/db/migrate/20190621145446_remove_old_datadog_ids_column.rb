# frozen_string_literal: true
class RemoveOldDatadogIdsColumn < ActiveRecord::Migration[5.2]
  def change
    remove_column :stages, :datadog_monitor_ids
  end
end
