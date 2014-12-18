class CreateMacros < ActiveRecord::Migration
  def change
    create_table :macros do |t|
      t.string :name, null: false
      t.string :reference, null: false
      t.text :command, null: false
      t.belongs_to :project, :user
      t.timestamps
    end

    create_table :macro_commands do |t|
      t.belongs_to :macro, :command
      t.integer :position, default: 0, null: false
      t.timestamps
    end
  end
end
