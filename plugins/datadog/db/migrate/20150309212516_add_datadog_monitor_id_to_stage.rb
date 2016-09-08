# frozen_string_literal: true
class AddDatadogMonitorIdToStage < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.string :datadog_monitor_ids, limit: 255
    end
  end
end
