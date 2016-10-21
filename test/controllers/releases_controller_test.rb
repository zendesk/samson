# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReleasesController do
  let(:project) { projects(:test) }
  let(:release) { releases(:test) }

  as_a_viewer do
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo

    describe "#show" do
      it "renders" do
        get :show, params: {project_id: project.to_param, id: release.version}
        assert_response :success
      end

      it "fails to render unknown release" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: 123}
        end
      end
    end

    describe "#flow" do
      def get_flow
        get :flow, params: {project_id: project.to_param, id: release.version}
      end

      with_env RELEASE_FLOW: "pod100|pod1,pod2"

      it "renders" do
        get_flow
        assert_template :flow

        assigns[:release_flow].must_equal [
          [stages(:test_staging)],["pod100"], [stages(:test_production),["pod1", "pod2"]]
        ]
      end

      it "renders missing stages" do
        DeployGroupsStage.delete_all
        get_flow
        assert_template :flow

        assigns[:release_flow].must_equal [
          [nil, ["pod100"]], [nil, ["pod1", "pod2"]]
        ]
      end
    end

    describe "#index" do
      it "renders" do
        get :index, params: {project_id: project.to_param}
        assert_response :success
      end
    end
  end

  as_a_project_deployer do
    describe "#create" do
      let(:release_params) { {commit: "abcd"} }
      before { GITHUB.stubs(:create_release) }

      it "creates a new release" do
        assert_difference "Release.count", +1 do
          post :create, params: {project_id: project.to_param, release: release_params}
          assert_redirected_to "/projects/foo/releases/v124"
        end
      end
    end

    describe "#new" do
      it "renders" do
        get :new, params: {project_id: project.to_param}
        assert_response :success
      end
    end
  end
end
