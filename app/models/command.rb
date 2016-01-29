class Command < ActiveRecord::Base
  has_many :stage_command
  has_many :stages, through: :stage_command
  has_many :macro_commands
  has_many :macros, through: :macro_commands

  belongs_to :project

  validates :command, presence: true

  def self.global
    where(project_id: nil)
  end

  # own commands in front then all available
  def self.for_object(object)
    (object.commands + Command.for_project(object.project)).uniq
  end

  def self.for_project(project)
    if project && project.persisted?
      where('project_id IS NULL OR project_id = ?', project.id)
    else
      global
    end
  end

  def global?
    project_id.nil?
  end

  def usages
    stages + macros
  end

  def self.usage_ids
    MacroCommand.pluck(:command_id) + StageCommand.pluck(:command_id)
  end
end
