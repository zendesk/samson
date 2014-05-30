class CreateStageCommands < ActiveRecord::Migration
  def change
    create_table :stage_commands do |t|
      t.belongs_to :stage
      t.belongs_to :command
      t.integer :position, default: 0, null: false
      t.timestamps
    end
  end
end
