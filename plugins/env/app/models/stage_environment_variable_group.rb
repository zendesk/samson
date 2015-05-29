class StageEnvironmentVariableGroup < ActiveRecord::Base
  belongs_to :stage
  belongs_to :environment_variable_group
end
