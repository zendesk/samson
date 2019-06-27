# frozen_string_literal: true
class MigrateDatadogMonitorsToTable < ActiveRecord::Migration[5.2]
  class Stage < ActiveRecord::Base
  end

  class DatadogMonitorQuery < ActiveRecord::Base
  end

  def change
    create_table :datadog_monitor_queries do |t|
      t.string :query, null: false
      t.integer :stage_id, null: false
      t.index :stage_id
    end

    Stage.where("datadog_monitor_ids is NOT NULL AND datadog_monitor_ids != ''").each do |stage|
      stage.datadog_monitor_ids.to_s.split(/, ?/).each do |id|
        DatadogMonitorQuery.create!(query: id, stage_id: stage.id)
      end
    end
  end
end
