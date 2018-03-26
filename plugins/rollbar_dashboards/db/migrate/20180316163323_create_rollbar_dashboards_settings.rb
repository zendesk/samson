# frozen_string_literal: true

class CreateRollbarDashboardsSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :rollbar_dashboards_settings do |t|
      t.string :base_url, null: false
      t.string :read_token, null: false
      t.references :project, index: true, null: false
      t.timestamps
    end
  end
end
