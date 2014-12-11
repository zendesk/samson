class UsersIndexDeletedAt < ActiveRecord::Migration
  def change
    add_index :users, [:external_id, :deleted_at]
    remove_index :users, column: :external_id
  end
end
