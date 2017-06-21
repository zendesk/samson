# frozen_string_literal: true
class Command < ActiveRecord::Base
  audited

  has_many :stage_commands
  has_many :stages, through: :stage_commands
  has_many :projects, foreign_key: :build_command_id

  belongs_to :project, optional: true

  validates :command, presence: true

  around_save :record_change_in_stage_audit, if: :command_changed?

  def self.global
    where(project_id: nil)
  end

  # used commands in front then all available
  def self.for_object(object)
    usages = usage_ids
    available = Command.for_project(object.project).sort_by { |c| -usages.count(c.id) }
    (object.commands + available).uniq
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

  private

  def record_change_in_stage_audit
    old = stages.map { |s| [s, s.script] }
    yield
    old.each do |s, script_was|
      s.commands.reload
      s.record_script_change script_was
    end
  end
end
