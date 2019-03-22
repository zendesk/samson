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

  # used commands in front then all available
  def self.for_stage(stage)
    usages = usage_ids
    available = Command.for_project(stage.project).sort_by { |c| -usages.count(c.id) }
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

  private

  def ensure_unused
    return if project&.deleted_at
    if usage_ids.any?
      errors.add(:base, 'Can only delete when unused.')
      throw(:abort)
    end
  end
end
