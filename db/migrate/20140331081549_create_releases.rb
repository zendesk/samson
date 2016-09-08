# frozen_string_literal: true
class CreateReleases < ActiveRecord::Migration[4.2]
  def change
    create_table :releases do |t|
      t.integer :project_id, null: false
      t.string :commit, null: false
      t.integer :number, default: 1
      t.integer :author_id, null: false
      t.string :author_type, null: false

      t.timestamps

      t.index [:project_id, :number], unique: true
    end
  end
end
