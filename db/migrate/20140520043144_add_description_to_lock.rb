# frozen_string_literal: true
class AddDescriptionToLock < ActiveRecord::Migration[4.2]
  def change
    add_column :locks, :description, :string
  end
end
