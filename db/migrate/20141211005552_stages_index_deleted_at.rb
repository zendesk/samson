class StagesIndexDeletedAt < ActiveRecord::Migration
  def change
    add_index :stages, [:project_id, :permalink, :deleted_at], length: { permalink: 191 }
    remove_index :stages, column: [:project_id, :permalink]
  end
end
