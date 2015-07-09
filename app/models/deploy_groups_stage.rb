class DeployGroupsStage < ActiveRecord::Base
  belongs_to :stage, touch: true
  belongs_to :deploy_group
end
