class AddDashboardToStages < ActiveRecord::Migration
  def change
    add_column :stages, :dashboard, :text
  end
end
