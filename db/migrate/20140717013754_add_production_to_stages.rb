class AddProductionToStages < ActiveRecord::Migration
  def change
    add_column :stages, :production, :boolean, default: nil
  end
end
