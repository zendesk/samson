# frozen_string_literal: true
class EnvironmentVariableGroup < ActiveRecord::Base
  include AcceptsEnvironmentVariables

  default_scope -> { order(:name) }

  has_many :project_environment_variable_groups, dependent: :destroy
  has_many :projects, through: :project_environment_variable_groups

  validates :name, presence: true
  around_save :record_environment_variable_change_in_projects_audits

  private

  def record_environment_variable_change_in_projects_audits
    old = projects.map { |p| [p, p.serialized_environment_variables] }
    yield
    old.each do |p, env_was|
      p.environment_variable_groups.reload
      p.record_environment_variable_change env_was
    end
  end
end
