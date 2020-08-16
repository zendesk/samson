# frozen_string_literal: true
class Command < ActiveRecord::Base
  extend AuditOnAssociation

  audited
  audits_on_association(:stages, :stage_commands, audit_name: :script, &:script)

  has_many :stage_commands, dependent: nil
  has_many :stages, through: :stage_commands, inverse_of: :commands
  has_many :projects, foreign_key: :build_command_id, dependent: nil, inverse_of: :build_command

  belongs_to :project, optional: true, inverse_of: :commands

  validates :command, presence: true

  before_destroy :ensure_unused

  def self.global
    where(project_id: nil)
  end

  # stage commands, then project commands by usage, then global commands by usage
  def self.for_stage(stage)
    usages = usage_ids
    available = Command.for_project(stage.project).sort_by { |c| [c.global? ? 1 : 0, -usages.count(c.id)] }
    (stage.commands + available).uniq
  end

  def self.for_project(project)
    if project&.persisted?
      where('project_id IS NULL OR project_id = ?', project.id)
    else
      global
    end
  end

  def global?
    project_id.nil?
  end

  def usages
    stages + projects
  end

  def usage_ids
    self.class.usage_ids.select { |id| id == self.id }
  end

  def self.usage_ids
    StageCommand.pluck(:command_id) +
    Project.pluck(:build_command_id).compact
  end

  def self.cleanup_global
    global.find_each do |command|
      project_ids = command.usages.map { |u| u.is_a?(Project) ? u.id : u.project_id }
      case project_ids.size
      when 0 then command.destroy
      when 1 then command.update_attribute(:project_id, project_ids.first)
      end
    end
  end

  private

  def ensure_unused
    return if project&.deleted_at
    if usage_ids.any?
      errors.add :base, 'Can only delete when unused.'
      throw :abort
    end
  end
end
Samson::Hooks.load_decorators(Command)
