# frozen_string_literal: true
class CreateStars < ActiveRecord::Migration[4.2]
  def change
    create_table :stars do |t|
      t.integer :user_id, null: false
      t.integer :project_id, null: false

      t.timestamps

      t.index [:user_id, :project_id], unique: true
    end
  end
end
