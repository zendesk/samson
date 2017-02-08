# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BuildsController do
  let(:project) { projects(:test) }

  as_a_viewer do
    before { @request_format = :json }
    unauthorized :post, :create, project_id: :foo
  end

  as_a_project_deployer do
    describe "#create" do
      let(:digest) { "foo.com/bar@sha256:#{"a" * 64}" }
      let(:build_params) do
        {
          docker_repo_digest: digest,
          git_sha: 'aaaa' * 10,
          git_ref: 'reff',
          source_url: 'https://source.url'
        }
      end

      before do
        GitRepository.any_instance.stubs(:update_local_cache!)
        GitRepository.any_instance.stubs(:commit_from_ref).with('reff').returns('some-commit')
      end

      it "creates" do
        assert_difference "Build.count", +1 do
          post :create, params: {build: build_params, project_id: project}, format: :json
          assert_response :created
        end
        build = Build.last
        build.creator.must_equal user
        build.project.must_equal project
        build.git_sha.must_equal 'aaaa' * 10
        build.git_ref.must_equal 'reff'
        build.source_url.must_equal 'https://source.url'
        build.docker_repo_digest.must_equal digest
      end

      it "fails nicely without docker_repo_digest" do
        post :create, params: {build: build_params.except(:docker_repo_digest), project_id: project}, format: :json
        assert_response :bad_request
      end

      it "fails nicely without git_sha" do
        post :create, params: {build: build_params.except(:git_sha), project_id: project}, format: :json
        assert_response :bad_request
      end
    end
  end
end
