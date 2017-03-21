# frozen_string_literal: true
Project.class_eval do
  include AcceptsEnvironmentVariables

  has_many :project_environment_variable_groups
  has_many :environment_variable_groups, through: :project_environment_variable_groups, dependent: :destroy
end
