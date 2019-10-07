# frozen_string_literal: true
class AddMonitorsToProjects < ActiveRecord::Migration[5.2]
  class DatadogMonitorQuery < ActiveRecord::Base
  end

  # we leave stage_id around so the server does not crash and delete it in the next migration
  def change
    add_column :datadog_monitor_queries, :scope_id, :integer
    add_column :datadog_monitor_queries, :scope_type, :string
    DatadogMonitorQuery.reset_column_information

    DatadogMonitorQuery.find_each do |query|
      query.update_columns(scope_id: query.stage_id, scope_type: "Stage")
    end

    change_column_null :datadog_monitor_queries, :scope_id, false
    change_column_null :datadog_monitor_queries, :scope_type, false
    change_column_null :datadog_monitor_queries, :stage_id, true
  end
end
