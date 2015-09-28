require_relative '../test_helper'

describe ReleasesController do
  let(:project) { projects(:test) }
  let(:release) { releases(:test) }

  as_a_viewer do
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo

    describe "#show" do
      it "renders" do
        get :show, project_id: project.to_param, id: release.version
        assert_response :success
      end

      it "fails to render unknown release" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: project.to_param, id: 123
        end
      end
    end

    describe "#index" do
      it "renders" do
        get :index, project_id: project.to_param
        assert_response :success
      end
    end
  end

  as_a_deployer do
    describe "#create" do
      let(:release_params) { { commit: "abcd" } }
      before { GITHUB.stubs(:create_release) }

      it "creates a new release" do
        assert_difference "Release.count", +1 do
          post :create, project_id: project.to_param, release: release_params
          assert_redirected_to "/projects/foo/releases/v124"
        end
      end
    end

    describe "#new" do
      it "renders" do
        get :new, project_id: project.to_param
        assert_response :success
      end
    end
  end

  as_a_viewer_project_deployer do
    describe "#create" do
      let(:release_params) { { commit: "abcd" } }
      before { GITHUB.stubs(:create_release) }

      it "creates a new release" do
        assert_difference "Release.count", +1 do
          post :create, project_id: project.to_param, release: release_params
          assert_redirected_to "/projects/foo/releases/v124"
        end
      end
    end

    describe "#new" do
      it "renders" do
        get :new, project_id: project.to_param
        assert_response :success
      end
    end
  end
end
