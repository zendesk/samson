# frozen_string_literal: true
class CreateMacros < ActiveRecord::Migration[4.2]
  def change
    create_table :macros do |t|
      t.string :name, null: false
      t.string :reference, null: false
      t.text :command, null: false
      t.belongs_to :project, :user
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :macros, [:project_id, :deleted_at]

    create_table :macro_commands do |t|
      t.belongs_to :macro, :command
      t.integer :position, default: 0, null: false
      t.timestamps
    end
  end
end
