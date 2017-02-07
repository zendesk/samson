# frozen_string_literal: true
class AddBuildCommandToProjects < ActiveRecord::Migration[5.0]
  def change
    add_column :projects, :build_command_id, :integer
    add_index :projects, :build_command_id
    add_index :macro_commands, :command_id
    add_index :macro_commands, :macro_id
    add_index :stage_commands, :command_id
    add_index :stage_commands, :stage_id
  end
end
