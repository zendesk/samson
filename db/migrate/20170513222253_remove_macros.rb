# frozen_string_literal: true
class RemoveMacros < ActiveRecord::Migration[5.1]
  def up
    drop_table :macros
    drop_table :macro_commands
  end

  def down
  end
end
