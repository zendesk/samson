Stage.class_eval do
  include AcceptsEnvironmentVariables

  has_many :stage_environment_variable_groups
  has_many :environment_variable_groups, through: :stage_environment_variable_groups
end
