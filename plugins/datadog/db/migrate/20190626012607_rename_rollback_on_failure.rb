# frozen_string_literal: true
class RenameRollbackOnFailure < ActiveRecord::Migration[5.2]
  def change
    rename_column :datadog_monitor_queries, :rollback_on_alert, :fail_deploy_on_alert
  end
end
