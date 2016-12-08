# frozen_string_literal: true
class BumpLockDescription < ActiveRecord::Migration[5.0]
  def change
    change_column :locks, :description, :string, limit: 1024
  end
end
