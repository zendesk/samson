class StagesIndexDeletedAt < ActiveRecord::Migration
  def change
    add_index :stages, [:project_id, :permalink, :deleted_at]
    remove_index :stages, column: [:project_id, :permalink]
  end
end
