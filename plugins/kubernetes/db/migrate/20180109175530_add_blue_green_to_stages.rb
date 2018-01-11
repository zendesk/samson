class AddBlueGreenToStages < ActiveRecord::Migration[5.1]
  def change
    add_column :stages, :blue_green, :boolean, default: false, null: false
  end
end
