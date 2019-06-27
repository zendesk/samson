# frozen_string_literal: true
class AddEnvironmentToLock < ActiveRecord::Migration[5.0]
  class Lock < ActiveRecord::Base
  end

  def up
    add_column :locks, :resource_type, :string
    Lock.where.not(stage_id: nil).update_all(resource_type: 'Stage')
    remove_index :locks, [:stage_id, :deleted_at, :user_id]

    rename_column :locks, :stage_id, :resource_id
    add_index :locks, [:resource_id, :resource_type, :deleted_at], unique: true, length: {resource_type: 40}
  end

  def down
    remove_index :locks, [:resource_id, :resource_type, :deleted_at]
    remove_column :locks, :resource_type

    rename_column :locks, :resource_id, :stage_id
    add_index :locks, [:stage_id, :deleted_at, :user_id]
  end
end
