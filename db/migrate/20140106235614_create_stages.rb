# frozen_string_literal: true
class CreateStages < ActiveRecord::Migration[4.2]
  def change
    create_table :stages do |t|
      t.string :name, null: false
      t.text :command
      t.integer :project_id, null: false

      t.timestamps
    end
  end
end
