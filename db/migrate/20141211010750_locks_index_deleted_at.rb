class LocksIndexDeletedAt < ActiveRecord::Migration
  def change
    add_index :locks, [:stage_id, :deleted_at, :user_id]
  end
end
