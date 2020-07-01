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
    check_suite_response = {check_suites: [{conclusion: 'success', id: 1}]}
    check_run_response = {
      check_runs: [
        {
          conclusion: 'success',
          output: {summary: '<p>Huzzah!</p>'},
          name: 'Travis CI',
          html_url: 'https://coolbeans.com',
          started_at: Time.now.iso8601,
          check_suite: {id: 1}
        }
      ]
    }

    stub_github_api(
      "repos/bar/foo/commits/abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd",
      sha: "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd"
    )
    stub_github_api "repos/bar/foo/commits/abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd/status", status_response
    stub_github_api "repos/bar/foo/commits/abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd/check-suites", check_suite_response
    stub_github_api "repos/bar/foo/commits/abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd/check-runs", check_run_response
  end

  as_a :viewer do
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

  as_a :project_deployer do
    describe "#create" do
      let(:release_params) { {commit: "abcd"} }
      before do
        GITHUB.expects(:commit).with("bar/foo", "abcd").returns(stub(sha: 'a' * 40))
        GITHUB.stubs(:create_release)
      end

      it "creates a new release" do
        GitRepository.any_instance.expects(:fuzzy_tag_from_ref).with('abcd').returns("v2")
        GITHUB.expects(:commit).with("bar/foo", "v124").returns(stub(sha: 'a' * 40))

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
