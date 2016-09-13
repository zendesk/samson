# frozen_string_literal: true
class AddUserExternalId < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :external_id, :string
    add_index :users, :external_id, unique: true, length: 191
  end
end
