# frozen_string_literal: true
class RemoveMacrosCommand < ActiveRecord::Migration[4.2]
  class OldMacro < ActiveRecord::Base
    self.table_name = :macros
  end

  class OldMacroCommand < ActiveRecord::Base
    self.table_name = :macro_commands
  end

  def up
    OldMacro.find_each do |m|
      next unless command = m.command.presence
      max = OldMacroCommand.where(macro_id: m.id).maximum(:position) || 0
      c = Command.create!(command: command, project_id: m.project_id)
      OldMacroCommand.create!(position: max + 1, command_id: c.id, macro_id: m.id)
    end

    remove_column :macros, :command
  end

  def down
    add_column :macros, :command, :text, null: false, default: ""
  end
end
