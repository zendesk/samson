class Command < ActiveRecord::Base
  has_many :stage_commands
  has_many :stages, through: :stage_commands
  has_many :macro_commands
  has_many :macros, through: :macro_commands

  belongs_to :project

  validates :command, presence: true

  after_save :trigger_stage_change

  def self.global
    where(project_id: nil)
  end

  # own commands in front then all available
  def self.for_object(object)
    usages = usage_ids
    available = Command.for_project(object.project).sort_by { |c| -usages.count(c.id) }
    (object.commands + available).uniq
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

  private

  def trigger_stage_change
    stages.each(&:record_script_change)
  end
end
