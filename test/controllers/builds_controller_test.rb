# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe BuildsController do
  include GitRepoTestHelper

  let(:tmp_dir) { Dir.mktmpdir }
  let(:project_repo_url) { repo_temp_dir }
  let(:project) { projects(:test).tap { |p| p.repository_url = project_repo_url } }
  let(:default_build) do
    project.builds.create!(name: 'master branch', git_ref: 'master', git_sha: 'a' * 40, creator: user)
  end
  let(:build) { builds(:docker_build) }

  before do
    create_repo_with_an_additional_branch('test_branch')
  end

  def stub_git_reference_check(returns: false)
    GitRepository.any_instance.stubs(:commit_from_ref).returns(returns)
  end

  it "recognizes deprecated api route" do
    assert_recognizes(
      {controller: 'builds', action: 'create', project_id: 'foo'},
      path: "api/projects/foo/builds", method: :post
    )
  end

  as_a_viewer do
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
        project.builds.create!(creator: user, name: 'test branch', git_ref: 'test_branch', git_sha: 'a' * 40)
        project.builds.create!(creator: user, name: 'master branch', git_ref: 'master', git_sha: 'b' * 40)
        get :index, params: {project_id: project.to_param}
        assert_response :ok
        @response.body.must_include 'test branch'
        @response.body.must_include 'master branch'
      end

      it 'can search for sha' do
        get :index, params: {project_id: project.to_param, search: {git_sha: build.git_sha}}
        assigns(:builds).must_equal [build]
      end

      it 'does not blow up when setting time_format' do
        get :index, params: {search: {time_format: 'relative'}}
        assert_response :success
      end

      describe "external" do
        it "ignores search for external blank" do
          get :index, params: {search: {external: ''}}
          assigns(:builds).count.must_equal Build.count
        end

        it "can search for external YES" do
          build.update_column(:external_id, 123)
          get :index, params: {search: {external: 'YES'}}
          assigns(:builds).must_equal [build]
        end

        it "can search for external NO" do
          Build.where.not(id: build.id).all.each { |b| b.update_column :external_id, b.id }
          get :index, params: {search: {external: 'NO'}}
          assigns(:builds).must_equal [build]
        end

        it "cannot search for unknown external" do
          assert_raises do
            get :index, params: {search: {external: 'FOOBAR'}}
          end
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
      before { default_build }

      it 'displays information about the build' do
        get :show, params: {project_id: project.to_param, id: default_build.id}
        assert_response :ok
        @response.body.must_include default_build.name
      end

      it 'displays the output of docker builds' do
        default_build.create_docker_job
        default_build.save!

        get :show, params: {project_id: project.to_param, id: default_build.id}
        assert_response :ok
        @response.body.must_include 'Docker Build Output'
      end
    end
  end

  as_a_project_deployer do
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
            build: { name: 'Test creation', git_ref: 'master', description: 'hi there' }.merge(attributes),
            format: format
          }
        )
      end

      let(:git_sha) { '0123456789012345678901234567890123456789' }

      before do
        stub_git_reference_check(returns: git_sha)
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
        create source_url: 'http://foo.com'
        Build.last.external_url.must_equal 'http://foo.com'
      end

      it 'can set dockerfile and image_name' do
        create dockerfile: 'bar', image_name: 'foo'
        build = Build.last
        build.dockerfile.must_equal 'bar'
        build.image_name.must_equal 'foo'
      end

      it 'updates a build via external_id' do
        build = Build.last
        build.update_columns(external_id: 'foo', external_status: 'running', docker_repo_digest: nil)

        digest = 'foo.com/test@sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c'
        create external_id: 'foo', external_status: 'succeeded', docker_repo_digest: digest, format: :json
        assert_response :success

        build.reload
        build.external_status.must_equal 'succeeded'
        build.docker_repo_digest.must_equal digest
      end

      it 'starts the build' do
        DockerBuilderService.any_instance.expects(:run)
        create
      end

      it "does not start the build when there were errors" do
        DockerBuilderService.any_instance.expects(:run).never
        stub_git_reference_check(returns: false)
        create
      end

      it "does not start the build when build is external" do
        DockerBuilderService.any_instance.expects(:run).never
        create external_id: "123"
      end

      describe "when building is disabled" do
        before { project.update_column :docker_image_building_disabled, true }

        it "does not create to build" do
          refute_difference 'Build.count' do
            create
            assert_redirected_to project_builds_path(project)
            assert flash[:alert]
          end
        end

        it "creates when digest was given" do
          assert_difference 'Build.count', +1 do
            create git_sha: 'a' * 40, docker_repo_digest: builds(:docker_build).docker_repo_digest
            assert_redirected_to project_build_path(project, Build.last)
            refute flash[:alert]
          end
        end

        it "creates when external_id was given" do
          assert_difference 'Build.count', +1 do
            create git_sha: 'a' * 40, external_id: 'foobar'
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
      before { default_build }

      it 'renders' do
        get :edit, params: {project_id: project.to_param, id: default_build.id}
        assert_response :ok
        @response.body.must_include default_build.name
      end
    end

    describe "#update" do
      def update(params = {name: 'New updated name!'})
        put :update, params: {project_id: project.to_param, id: default_build.id, build: params, format: format}
      end

      before { default_build }

      describe "html" do
        let(:format) { 'html' }

        it 'updates the build' do
          update
          assert_response :redirect
          default_build.reload.name.must_equal 'New updated name!'
        end

        it "renders when it fails to update" do
          Build.any_instance.expects(:update_attributes).returns false
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
          default_build.reload.name.must_equal 'New updated name!'
        end

        it "renders when it fails to update" do
          Build.any_instance.expects(:update_attributes).returns false
          update
          assert_response :unprocessable_entity
          response.body.must_equal "{\"status\":422,\"error\":{}}"
        end
      end
    end

    describe "#build_docker_image" do
      def build
        post :build_docker_image, params: {project_id: project.to_param, id: default_build.id, format: format}
      end

      before { DockerBuilderService.any_instance.expects(:run) }

      describe 'html' do
        let(:format) { 'html' }

        it "builds an image" do
          build
          assert_redirected_to [project, default_build]
        end

        it "does not build when disabled" do
          DockerBuilderService.any_instance.unstub(:run)
          DockerBuilderService.any_instance.expects(:run).never
          project.update_column :docker_image_building_disabled, true
          build
          assert_redirected_to project_builds_path(project)
          assert flash[:alert]
        end
      end

      describe 'json' do
        let(:format) { 'json' }

        it "builds an image" do
          build
          assert_response :success
        end
      end
    end
  end
end
