# frozen_string_literal: true
class ConvertMacrosToStages < ActiveRecord::Migration[5.1]
  class MacroCommand < ActiveRecord::Base
  end

  class StageCommand < ActiveRecord::Base
  end

  class Macro < ActiveRecord::Base
    has_many :command_associations, class_name: "MacroCommand", dependent: :destroy
    has_many :commands, -> { order("macro_commands.position ASC").auto_include(false) }, through: :command_associations
  end

  class Stage < ActiveRecord::Base
    has_many :command_associations, class_name: "StageCommand", dependent: :destroy
    has_many :commands, -> { order("stage_commands.position ASC").auto_include(false) }, through: :command_associations
  end

  def up
    Macro.find_each do |macro|
      begin
        Stage.create!(
          macro.attributes.slice("project_id", "name", "deleted_at", "created_at").merge(
            confirm: false,
            permalink: macro.name.parameterize,
            no_code_deployed: true,
            no_reference_selection: true,
            order: 66, # all go to the back
            command_associations: macro.command_associations.map do |c|
              StageCommand.new(c.attributes.slice("command_id", "position", "created_at"))
            end
          )
        )
        macro.update_column(:deleted_at, Time.now) unless macro.deleted_at
      rescue
        write $!
        write $!.backtrace
      end
    end
  end

  def down
  end
end
