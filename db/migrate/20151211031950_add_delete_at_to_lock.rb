# frozen_string_literal: true
class AddDeleteAtToLock < ActiveRecord::Migration
  def change
    add_column :locks, :delete_at, :datetime
  end
end
