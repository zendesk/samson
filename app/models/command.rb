class Command < ActiveRecord::Base
  has_many :stage_command
  has_many :stages, through: :stage_commands
  belongs_to :project

  validates :command, presence: true

  def self.global
    where(project_id: nil)
  end

  def self.for_project(project)
    where('project_id IS NULL OR project_id = ?', project.id)
  end

  def global?
    project_id.nil?
  end

  def name_alias
    name || command
  end

end
