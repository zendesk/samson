class ProjectEnvironmentVariableGroup < ActiveRecord::Base
  belongs_to :project
  belongs_to :environment_variable_group
end
