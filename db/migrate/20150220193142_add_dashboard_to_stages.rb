class AddDashboardToStages < ActiveRecord::Migration
  def change
    add_column :stages, :dashboard, :text, limit: 65535
  end
end
