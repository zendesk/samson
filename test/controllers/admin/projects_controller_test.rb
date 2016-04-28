require_relative '../../test_helper'

SingleCov.covered!

describe Admin::ProjectsController do
  as_a_deployer do
    unauthorized :get, :show, id: 1
  end

  as_a_project_admin do
    unauthorized :get, :show, id: 1
  end

  as_a_admin do
    describe "#shiw" do
      it "renders" do
        get :show, id: projects(:test)
        assert_template :show
      end
    end
  end
end
