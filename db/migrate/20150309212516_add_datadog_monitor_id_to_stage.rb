class AddDatadogMonitorIdToStage < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :datadog_monitor_ids
    end
  end
end
