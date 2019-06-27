# frozen_string_literal: true

class AddAccountAndProjectNameToRollbarDashboardsSettings < ActiveRecord::Migration[5.2]
  def change
    add_column :rollbar_dashboards_settings, :account_and_project_name, :string
  end
end
