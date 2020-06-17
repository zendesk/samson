# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe BuildsController do
  let(:project) { projects(:test) }
  let(:build) { builds(:docker_build) }

  def stub_git_reference_check(returns)
    Project.any_instance.stubs(:repo_commit_from_ref).returns(returns)
  end

  it "recognizes deprecated api route" do
    assert_recognizes(
      {controller: 'builds', action: 'create', project_id: 'foo'},
      path: "api/projects/foo/builds", method: :post
    )
  end

  as_a :viewer do
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :get, :edit, id: 1, project_id: :foo
    unauthorized :put, :update, id: 1, project_id: :foo
    unauthorized :post, :build_docker_image, id: 1, project_id: :foo

    describe '#index' do
      it 'works without builds' do
        get :index, params: {project_id: project.to_param}
        assert_response :ok
      end

      it 'displays basic build info' do
        stub_git_reference_check 'c' * 40
        project.builds.create!(creator: user, name: 'test branch', git_ref: 'test_branch', git_sha: 'a' * 40)
        project.builds.create!(creator: user, name: 'master branch', git_ref: 'master', git_sha: 'b' * 40)
        get :index, params: {project_id: project.to_param}
        assert_response :ok
        @response.body.must_include 'test branch'
        @response.body.must_include 'master branch'
      end

      it 'can search for sha' do
        get :index, params: {search: {git_commit: build.git_sha}}
        assigns(:builds).must_equal [build]
      end

      it 'can search for ref' do
        get :index, params: {search: {git_commit: build.git_ref}}
        assigns(:builds).must_equal [build]
      end

      describe "status" do
        it "ignores search for status blank" do
          get :index, params: {search: {status: ''}}
          assigns(:builds).count.must_equal Build.count
        end

        it "only allows valid search parameters" do
          assert_raises ActionController::UnpermittedParameters do
            get :index, params: {search: {foo: "bar"}}
          end
        end

        it "can search for external status" do
          build.update_column(:external_status, "succeeded")
          get :index, params: {search: {status: "succeeded"}}
          assigns(:builds).must_equal [build]
        end

        it "can search for internal status" do
          build.update_column(:docker_build_job_id, jobs(:succeeded_test).id)
          get :index, params: {search: {status: "succeeded"}}
          assigns(:builds).must_equal [build]
        end
      end

      it 'renders json without associations' do
        get :index, params: {project_id: project.to_param}, format: :json
        json = JSON.parse(@response.body)
        refute json['builds'][0].key?('project')
      end

      it "can render without a project" do
        get :index
        assigns(:builds).must_include builds(:docker_build)
      end
    end

    describe '#show' do
      it 'displays information about the build' do
        get :show, params: {project_id: build.project.to_param, id: build.id}
        assert_response :ok
        @response.body.must_include build.name
      end

      it 'displays the output of docker builds' do
        build.create_docker_job
        build.save! # store id on build
        get :show, params: {project_id: build.project.to_param, id: build.id}
        assert_response :ok
        @response.body.must_include 'Docker Build Output'
      end
    end
  end

  as_a :project_deployer do
    describe '#new' do
      it 'renders' do
        get :new, params: {project_id: project.to_param}
        assert_response :ok
      end

      it "does not render when disabled" do
        project.update_column :docker_image_building_disabled, true
        get :new, params: {project_id: project.to_param}
        assert_redirected_to project_builds_path(project)
        assert flash[:alert]
      end
    end

    describe "#create" do
      def create(attributes = {})
        format = attributes.delete(:format) || :html
        post(
          :create,
          params: {
            project_id: project.to_param,
            build: {name: 'Test creation', git_ref: 'master', description: 'hi there'}.merge(attributes),
            format: format
          }
        )
      end

      let(:git_sha) { '0123456789012345678901234567890123456789' }

      before do
        stub_git_reference_check(git_sha)
      end

      it 'can create a build' do
        create
        assert_response :redirect

        build = Build.last
        assert_equal('Test creation', build.name)
        assert_equal(git_sha, build.git_sha)
        assert_redirected_to project_build_path(project, build)
      end

      it 'can create a build with json' do
        create format: :json
        assert_response :created
        response.body.must_equal "{}"
      end

      it 'can use deprecated source_url' do
        create source_url: 'http://foo.com', git_sha: git_sha, dockerfile: 'foo'
        Build.last.external_url.must_equal 'http://foo.com'
      end

      it 'can set dockerfile and image_name' do
        create dockerfile: 'bar', image_name: 'foo'
        build = Build.last
        build.dockerfile.must_equal 'bar'
        build.image_name.must_equal 'foo'
      end

      it 'can create external build' do
        create external_url: 'http://foo.com', git_sha: git_sha, image_name: 'foo'
        Build.last.external_url.must_equal 'http://foo.com'
      end

      describe "updates external builds" do
        let(:digest) { 'foo.com/test@sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c' }
        let(:external_url) { 'https://blob.com/1234' }
        let(:create_args) do
          {
            git_sha: build.git_sha,
            external_status: 'succeeded',
            external_url: external_url,
            docker_repo_digest: digest,
            dockerfile: build.dockerfile,
            format: :json
          }
        end

        before do
          build.update_columns(external_status: 'running', external_url: external_url, docker_repo_digest: nil)
        end

        it 'creates a new build when external url changes for the same git sha' do
          assert_difference 'Build.count' do
            create create_args.merge(external_url: 'https://blob.com/1235')
            assert_response :success
          end

          build.reload
          build.external_status.must_equal 'running'
          build.docker_repo_digest.must_equal nil
          build.external_url.must_equal external_url

          new_build = Build.last
          new_build.external_status.must_equal 'succeeded'
          new_build.docker_repo_digest.must_equal digest
          new_build.external_url.must_equal 'https://blob.com/1235'
        end

        it 'updates existing running build when succeeded' do
          create create_args
          assert_response :success

          build.reload
          build.external_status.must_equal 'succeeded'
          build.docker_repo_digest.must_equal digest
          build.external_url.must_equal external_url
        end

        it 'allows updating a failed external build' do
          create create_args.merge(external_status: 'failed')
          assert_response :success

          build.reload
          build.external_status.must_equal 'failed'
          build.docker_repo_digest.must_equal digest
          build.external_url.must_equal external_url
        end

        it 'does not allow updating a succeeded build to prevent tampering' do
          build.update_columns docker_repo_digest: digest, external_status: 'succeeded'

          create create_args.merge(docker_repo_digest: digest.reverse)
          assert_response 422

          build.reload
          build.external_status.must_equal 'succeeded'
          build.docker_repo_digest.must_equal digest
          build.external_url.must_equal external_url
        end

        it 'returns no content for succeeded builds that have not changes' do
          build.update_columns(docker_repo_digest: digest, external_status: 'succeeded', description: 'hello')

          # duplicate success
          create create_args.merge(
            name: build.name,
            description: 'hello'
          )

          assert_response :ok
        end

        it 'retries when 2 requests come in at the exact same time and cause uniqueness error' do
          Build.any_instance.expects(:save).returns(true)
          Build.any_instance.expects(:save).raises(ActiveRecord::RecordNotUnique)
          create create_args.merge(external_status: 'failed')
          assert_response :success
        end
      end

      it 'starts the build' do
        DockerBuilderService.any_instance.expects(:run)
        create
      end

      it "does not start the build when there were errors" do
        DockerBuilderService.any_instance.expects(:run).never
        stub_git_reference_check(false)
        create
      end

      it "does not start the build when build is external" do
        DockerBuilderService.any_instance.expects(:run).never
        create external_status: "succeeded", git_sha: "a" * 40, dockerfile: 'foo'
      end

      describe "when building is disabled" do
        before { project.update_column :docker_image_building_disabled, true }

        it "does not create build" do
          refute_difference 'Build.count' do
            create
            assert_redirected_to project_builds_path(project)
            assert flash[:alert]
          end
        end

        it "creates finished external build" do
          assert_difference 'Build.count', +1 do
            create git_sha: 'a' * 40, docker_repo_digest: builds(:docker_build).docker_repo_digest, dockerfile: 'foo'
            assert_redirected_to project_build_path(project, Build.last)
            refute flash[:alert]
          end
        end

        it "creates for in-progress external build" do
          assert_difference 'Build.count', +1 do
            create git_sha: 'a' * 40, external_status: "pending", dockerfile: 'foo'
            assert_redirected_to project_build_path(project, Build.last)
            refute flash[:alert]
          end
        end
      end

      describe "with error" do
        let(:git_sha) { false }

        it "renders html error" do
          create
          assert_response :unprocessable_entity
          assert_template :new
        end

        it "renders json error" do
          create format: :json
          assert_response :unprocessable_entity
          JSON.parse(response.body).must_equal("status" => 422, "error" => {"git_ref" => ["is not a valid reference"]})
        end
      end
    end

    describe '#edit' do
      it 'renders' do
        get :edit, params: {project_id: build.project.to_param, id: build.id}
        assert_response :ok
        @response.body.must_include build.name
      end
    end

    describe "#update" do
      def update(params = {name: 'New updated name!'})
        put :update, params: {project_id: project.to_param, id: build.id, build: params, format: format}
      end

      describe "html" do
        let(:format) { 'html' }

        it 'updates the build' do
          update
          assert_response :redirect
          build.reload.name.must_equal 'New updated name!'
        end

        it "renders when it fails to update" do
          Build.any_instance.expects(:update).returns false
          update
          assert_template :edit
          assert_response :unprocessable_entity
        end

        it 'prevents changing the git ref' do
          assert_raises ActionController::UnpermittedParameters do
            update git_ref: 'test_branch'
          end
        end

        it 'prevents changing the git sha' do
          assert_raises ActionController::UnpermittedParameters do
            update git_sha: '0123456789012345678901234567890123456789'
          end
        end
      end

      describe "json" do
        let(:format) { 'json' }

        it 'updates the build' do
          update
          assert_response :success
          response.body.must_equal "{}"
          build.reload.name.must_equal 'New updated name!'
        end

        it "renders when it fails to update" do
          Build.any_instance.expects(:update).returns false
          update
          assert_response :unprocessable_entity
          response.body.must_equal "{\"status\":422,\"error\":{}}"
        end
      end
    end

    describe "#build_docker_image" do
      def build_docker_image
        post :build_docker_image, params: {project_id: project.to_param, id: build.id, format: format}
      end

      before { DockerBuilderService.any_instance.expects(:run) }

      describe 'html' do
        let(:format) { 'html' }

        it "builds an image" do
          build_docker_image
          assert_redirected_to [project, build]
        end

        it "does not build when disabled" do
          DockerBuilderService.any_instance.unstub(:run)
          DockerBuilderService.any_instance.expects(:run).never
          project.update_column :docker_image_building_disabled, true
          build_docker_image
          assert_redirected_to project_builds_path(project)
          assert flash[:alert]
        end
      end

      describe 'json' do
        let(:format) { 'json' }

        it "builds an image" do
          build_docker_image
          assert_response :success
        end
      end
    end
  end
end
