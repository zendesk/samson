# frozen_string_literal: true
class AddWarningToLocks < ActiveRecord::Migration
  def change
    add_column :locks, :warning, :boolean, default: false, null: false
  end
end
