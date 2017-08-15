# frozen_string_literal: true
class Command < ActiveRecord::Base
  extend AuditOnAssociation

  audited
  audits_on_association(:stages, :stage_commands, audit_name: :script, &:script)

  has_many :stage_commands
  has_many :stages, through: :stage_commands
  has_many :projects, foreign_key: :build_command_id

  belongs_to :project, optional: true

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

  def self.usage_ids
    StageCommand.pluck(:command_id) +
    Project.pluck(:build_command_id)
  end

  # We should not destroy the command if it is associated with any stages.
  # Also, we should not destroy the command if it is the build commands for multiple projects.
  #
  # It isn't possible through the UI to associate a build command with multiple projects.
  # However, it is possible through the API and the console to do this. So in the case that
  # this does happen, we should prevent such commands from being destroyed.
  #
  # When the build command is associated with only one project, it can be destroyed via this code path:
  # https://github.com/zendesk/samson/blob/master/app/controllers/build_commands_controller.rb#L13
  def unused?
    stages.empty? && projects.count <= 1
  end

  private

  def ensure_unused
    unless unused?
      errors.add(:base, 'Can only delete unused commands.')
      throw(:abort)
    end
  end
end
