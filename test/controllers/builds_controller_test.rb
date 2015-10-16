require_relative '../test_helper'

describe BuildsController do
  include GitRepoTestHelper

  let(:tmp_dir) { Dir.mktmpdir }
  let(:project_repo_url) { repo_temp_dir }
  let(:project) { projects(:test).tap { |p| p.repository_url = project_repo_url } }

  let(:default_build) { project.builds.create!(label: 'master branch', git_ref: 'master') }

  before do
    create_repo_with_an_additional_branch('test_branch')
  end

  def stub_git_reference_check(returns: false)
    GitRepository.any_instance.stubs(:setup_local_cache!).returns(true)
    GitRepository.any_instance.stubs(:commit_from_ref).returns(returns)
  end

  as_a_deployer do
    describe '#index' do
      it 'works with no builds' do
        get :index, project_id: project.to_param
        assert_response :ok
      end

      it 'displays basic build info' do
        project.builds.create!(label: 'test branch', git_ref: 'test_branch')
        project.builds.create!(label: 'master branch', git_ref: 'master')
        get :index, project_id: project.to_param
        assert_response :ok
        @response.body.must_include 'test branch'
        @response.body.must_include 'master branch'
      end
    end

    describe '#show' do
      before { default_build }

      it 'displays information about the build' do
        get :show, project_id: project.to_param, id: default_build.id
        assert_response :ok
        @response.body.must_include default_build.label
      end
    end

    describe 'creating a new build' do
      let(:git_sha) { '0123456789012345678901234567890123456789' }

      it 'displays the #new page' do
        get :new, project_id: project.to_param
        assert_response :ok
      end

      it 'can create a build' do
        stub_git_reference_check(returns: git_sha)

        post :create, project_id: project.to_param, build: { label: 'Test creation', git_ref: 'master', description: 'hi there' }
        assert_response :redirect

        new_build = Build.last
        assert_equal('Test creation', new_build.label)
        assert_equal(git_sha, new_build.git_sha)
        assert_redirected_to project_build_path(project, new_build)
      end

      it 'can create a build with same git_ref as previous' do
        Build.destroy_all
        stub_git_reference_check(returns: git_sha)

        post :create, project_id: project.to_param, build: { label: 'Test creation', git_ref: 'master', description: 'hi there' }
        Build.count.must_equal 1
        Build.all.last.label.must_equal 'Test creation'
        post :create, project_id: project.to_param, build: { label: 'Test creation 2', git_ref: 'master', description: 'hi there' }
        Build.count.must_equal 1
        Build.all.last.label.must_equal 'Test creation 2'
      end

      it 'handles errors' do
        stub_git_reference_check(returns: false)
        post :create, project_id: project.to_param, build: { label: 'Test creation', git_ref: 'INVALID REF' }
        assert_response 422
      end
    end

    describe 'editing a build' do
      before { default_build }

      it 'displays the #edit page' do
        get :edit, project_id: project.to_param, id: default_build.id
        assert_response :ok
        @response.body.must_include default_build.label
      end

      it 'updates the build' do
        put :update, project_id: project.to_param, id: default_build.id, build: { label: 'New updated label!' }
        assert_response :redirect
        default_build.reload
        assert_equal('New updated label!', default_build.label)
      end

      it 'prevents changing the git ref or sha' do
        assert_raises ActionController::UnpermittedParameters do
          put :update, project_id: project.to_param, id: default_build.id, build: { git_ref: 'test_branch' }
        end

        assert_raises ActionController::UnpermittedParameters do
          put :update, project_id: project.to_param, id: default_build.id, build: { git_sha: '0123456789012345678901234567890123456789' }
        end
      end
    end
  end

  as_a_project_deployer do
    describe '#index' do
      it 'works with no builds' do
        get :index, project_id: project.to_param
        assert_response :ok
      end

      it 'displays basic build info' do
        project.builds.create!(label: 'test branch', git_ref: 'test_branch')
        project.builds.create!(label: 'master branch', git_ref: 'master')
        get :index, project_id: project.to_param
        assert_response :ok
        @response.body.must_include 'test branch'
        @response.body.must_include 'master branch'
      end
    end

    describe '#show' do
      before { default_build }

      it 'displays information about the build' do
        get :show, project_id: project.to_param, id: default_build.id
        assert_response :ok
        @response.body.must_include default_build.label
      end
    end

    describe 'creating a new build' do
      it 'displays the #new page' do
        get :new, project_id: project.to_param
        assert_response :ok
      end

      it 'can create a build' do
        git_sha = '0123456789012345678901234567890123456789'
        stub_git_reference_check(returns: git_sha)

        post :create, project_id: project.to_param, build: { label: 'Test creation', git_ref: 'master', description: 'hi there' }
        assert_response :redirect

        new_build = Build.last
        assert_equal('Test creation', new_build.label)
        assert_equal(git_sha, new_build.git_sha)
        assert_redirected_to project_build_path(project, new_build)
      end

      it 'handles errors' do
        stub_git_reference_check(returns: false)
        post :create, project_id: project.to_param, build: { label: 'Test creation', git_ref: 'INVALID REF' }
        assert_response 422
      end
    end

    describe 'editing a build' do
      before { default_build }

      it 'displays the #edit page' do
        get :edit, project_id: project.to_param, id: default_build.id
        assert_response :ok
        @response.body.must_include default_build.label
      end

      it 'updates the build' do
        put :update, project_id: project.to_param, id: default_build.id, build: { label: 'New updated label!' }
        assert_response :redirect
        default_build.reload
        assert_equal('New updated label!', default_build.label)
      end

      it 'prevents changing the git ref or sha' do
        assert_raises ActionController::UnpermittedParameters do
          put :update, project_id: project.to_param, id: default_build.id, build: { git_ref: 'test_branch' }
        end

        assert_raises ActionController::UnpermittedParameters do
          put :update, project_id: project.to_param, id: default_build.id, build: { git_sha: '0123456789012345678901234567890123456789' }
        end
      end
    end
  end
end
