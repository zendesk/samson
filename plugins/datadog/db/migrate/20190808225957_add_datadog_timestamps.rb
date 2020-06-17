# frozen_string_literal: true
class AddDatadogTimestamps < ActiveRecord::Migration[5.2]
  def change
    add_column :datadog_monitor_queries, :created_at, :datetime, default: Time.at(0), null: false
    add_column :datadog_monitor_queries, :updated_at, :datetime, default: Time.at(0), null: false
    change_column_default :datadog_monitor_queries, :created_at, nil
    change_column_default :datadog_monitor_queries, :updated_at, nil
  end
end
