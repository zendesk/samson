# frozen_string_literal: true
class AddUserRoles < ActiveRecord::Migration[4.2]
  def change
    change_table :users do |t|
      t.integer :role_id, null: false, default: 0
    end
  end
end
