# frozen_string_literal: true
class ProjectEnvironmentVariableGroup < ActiveRecord::Base
  belongs_to :project, inverse_of: :project_environment_variable_groups
  belongs_to :environment_variable_group, inverse_of: :project_environment_variable_groups
end
