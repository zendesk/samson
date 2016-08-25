# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroupsStage do
  describe "#destroy" do
    let(:deploy_groups_stage) do
      stages(:test_staging).deploy_groups_stages.first
    end

    it "destroys" do
      DeployGroupsStage.create!(stage: deploy_groups_stage.stage, deploy_group: deploy_groups(:pod2))
      DeployGroupsStage.create!(stage: stages(:test_production), deploy_group: deploy_groups_stage.deploy_group)
      assert_difference 'DeployGroupsStage.count', -1 do
        deploy_groups_stage.destroy
      end
    end
  end
end
