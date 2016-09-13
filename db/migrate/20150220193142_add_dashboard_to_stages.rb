# frozen_string_literal: true
class AddDashboardToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :dashboard, :text, limit: 65535
  end
end
