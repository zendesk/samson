# frozen_string_literal: true
class LocksIndexDeletedAt < ActiveRecord::Migration[4.2]
  def change
    add_index :locks, [:stage_id, :deleted_at, :user_id]
  end
end
