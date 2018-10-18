# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReleasesController do
  let(:project) { projects(:test) }
  let(:release) { releases(:test) }

  before do
    status_response = {
      state: "success",
      statuses: [
        {
          state: "success",
          context: "oompa/loompa",
          target_url: "https://chocolate-factory.com/test/wonka",
          description: "Ooompa Loompa!",
          updated_at: Time.now.iso8601,
          created_at: Time.now.iso8601
        }
      ]
    }

    headers = {
      "Content-Type" => "application/json",
    }

    stub_request(:get, "https://api.github.com/repos/bar/foo/commits/abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd/status").
      to_return(status: 200, body: status_response.to_json, headers: headers)
  end

  as_a_viewer do
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo

    describe "#show" do
      it "renders continuous versions" do
        get :show, params: {project_id: project.to_param, id: release.version}
        assert_template 'show'
      end

      it "renders major-minor versions" do
        release.update_column :number, '12.3'
        get :show, params: {project_id: project.to_param, id: release.version}
        assert_response :success
      end

      it "fails to render unknown release" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: "v321"}
        end
      end

      it "renders row content for xhr requests" do
        get :show, params: {project_id: project.to_param, id: release.version}, xhr: true
        assert_template 'row_content'
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
      before do
        GitRepository.any_instance.expects(:commit_from_ref).with('abcd').returns('a' * 40)
        GITHUB.stubs(:create_release)
      end

      it "creates a new release" do
        GitRepository.any_instance.expects(:fuzzy_tag_from_ref).with('abcd').returns("v2")
        GitRepository.any_instance.expects(:commit_from_ref).with('v124').returns('a' * 40)

        assert_difference "Release.count", +1 do
          post :create, params: {project_id: project.to_param, release: release_params}
          assert_redirected_to "/projects/foo/releases/v124"
        end
      end

      it "rescues bad input and redirects back to new" do
        release_params[:number] = "1A"
        post :create, params: {project_id: project.to_param, release: release_params}
        assert_template :new
      end
    end

    describe "#new" do
      it "renders" do
        get :new, params: {project_id: project.to_param}
        assert_response :success
        assigns(:release).number.must_equal "124" # next after 123
      end
    end
  end
end
