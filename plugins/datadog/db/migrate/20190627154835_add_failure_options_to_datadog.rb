# frozen_string_literal: true
class AddFailureOptionsToDatadog < ActiveRecord::Migration[5.2]
  def change
    remove_column :datadog_monitor_queries, :fail_deploy_on_alert
    add_column :datadog_monitor_queries, :failure_behavior, :string
  end
end
