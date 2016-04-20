class AddDatadogMonitorIdToStage < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :datadog_monitor_ids, limit: 255
    end
  end
end
