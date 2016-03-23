class ConvertMacros < ActiveRecord::Migration
  class OldMacro < ActiveRecord::Base
    self.table_name = :macros
    has_soft_deletion default_scope: true
    belongs_to :project
    belongs_to :user
    has_many :macro_commands, autosave: true
    has_many :commands, -> { order('macro_commands.position ASC') }, through: :macro_commands, auto_include: false
  end

  def up
    add_column :stages, :type, :string, default: "Stage", null: false

    OldMacro.find_each do |m|
      ::Macro.create!(name: m.name, commands: m.commands, project: m.project)
    end
  end

  def down
    Stage.where(type: "Macro").each(&:destroy)
    remove_column :stages, :type
  end
end
