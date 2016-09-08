# frozen_string_literal: true
class AddDeleteAtToLock < ActiveRecord::Migration[4.2]
  def change
    add_column :locks, :delete_at, :datetime
  end
end
