class Macro < ActiveRecord::Base
  has_soft_deletion default_scope: true

  attr_writer :command

  belongs_to :project
  belongs_to :user

  has_many :macro_commands, autosave: true
  has_many :commands, -> { order('macro_commands.position ASC') },
    through: :macro_commands, auto_include: false

  validates :name, presence: true, uniqueness: { scope: [:project, :deleted_at] }
  validates :reference, presence: true

  before_save :build_new_project_command

  def command
    commands.map(&:command).join("\n")
  end

  def command_ids=(new_command_ids)
    super.tap do
      reorder_commands(new_command_ids.reject(&:blank?).map(&:to_i))
    end
  end

  private

  def build_new_project_command
    return unless @command.present?

    new_command = project.commands.build(command: @command)
    macro_commands.build(command: new_command).tap do
      reorder_commands
    end
  end

  def reorder_commands(command_ids = self.command_ids)
    macro_commands.each do |macro_command|
      macro_command.position = command_ids.index(macro_command.command_id) ||
        macro_commands.length
    end
  end
end
