# frozen_string_literal: true
class UsersIndexDeletedAt < ActiveRecord::Migration[4.2]
  def change
    add_index :users, [:external_id, :deleted_at], length: {external_id: 191}
    remove_index :users, column: :external_id
  end
end
