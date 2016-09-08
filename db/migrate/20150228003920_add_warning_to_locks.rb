# frozen_string_literal: true
class AddWarningToLocks < ActiveRecord::Migration[4.2]
  def change
    add_column :locks, :warning, :boolean, default: false, null: false
  end
end
