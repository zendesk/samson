# frozen_string_literal: true
class DeployGroupsStage < ActiveRecord::Base
  belongs_to :stage, touch: true
  belongs_to :deploy_group

  def destroy
    self.class.where(stage_id: stage_id, deploy_group_id: deploy_group_id).delete_all
  end
end
