require_relative '../test_helper'

describe DeployGroupsController do
  let(:deploy_group) { deploy_groups(:pod1) }

  as_a_viewer do
    describe "#show" do
      it "renders" do
        get :show, id: deploy_group
        assert_template :show
      end
    end
  end
end
