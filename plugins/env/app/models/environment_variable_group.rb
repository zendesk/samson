class EnvironmentVariableGroup < ActiveRecord::Base
  include AcceptsEnvironmentVariables

  default_scope -> { order(:name) }

  has_many :stage_environment_variable_groups
  has_many :stages, through: :stage_environment_variable_groups

  validates :name, presence: true
end
