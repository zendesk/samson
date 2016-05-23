# rubocop:disable Metrics/LineLength
require_relative '../test_helper'

SingleCov.covered!

describe KubernetesReleasesController do
  let(:project) { projects(:test) }
  let(:build) { builds(:docker_build) }
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:app_server) { kubernetes_roles(:app_server) }
  let(:resque_worker) { kubernetes_roles(:resque_worker) }
  let(:role_config_file) { read_kubernetes_sample_file('kubernetes_role_config_file.yml') }

  as_a_viewer do
    describe 'a GET to #index' do
      it_responds_with_unauthorized do
        get :index, project_id: project.permalink
      end
    end

    describe 'a POST to #create with a single role' do
      it_responds_with_unauthorized do
        post :create, project_id: project.permalink, authenticity_token:  set_form_authenticity_token
      end
    end

    describe 'a POST to #create with multiple roles' do
      it_responds_with_unauthorized do
        post :create, project_id: project.permalink, authenticity_token:  set_form_authenticity_token
      end
    end
  end

  as_a_deployer do
    describe 'a GET to #index' do
      before { current_release_count }

      it_responds_successfully do
        get :index, project_id: project.permalink
        assert_response_to_index(response)
      end
    end

    describe 'a POST to #create with a single role' do
      before do
        expect_file_contents_from_repo
        expect_deploy
        current_release_count
      end

      it_responds_successfully do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params, authenticity_token:  set_form_authenticity_token
        assert_response_to_create(response)
        assert_release_count(@current_release_count + 1)
      end
    end

    describe 'a POST to #create with multiple roles' do
      before do
        2.times { expect_file_contents_from_repo }
        expect_deploy
        current_release_count
      end

      it_responds_successfully do
        post :create, project_id: project.permalink, kubernetes_release: multiple_roles_release_params, authenticity_token:  set_form_authenticity_token
        assert_response_to_create(response)
        assert_release_count(@current_release_count + 1)
      end
    end

    describe 'a POST to #create with a missing build id' do
      before { current_release_count }

      it_responds_with_bad_request do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.except(:build_id), authenticity_token:  set_form_authenticity_token
        assert_response_with_errors(response)
        assert_release_count(@current_release_count)
      end
    end

    describe 'a POST to #create with missing deploy groups' do
      before { current_release_count }

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.except(:deploy_groups), authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.tap { |params| params[:deploy_groups].clear }, authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end
    end

    describe 'a POST to #create with missing roles' do
      before { current_release_count }

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.tap { |params| params[:deploy_groups].each { |dg| dg.delete(:roles) } }, authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.tap { |params| params[:deploy_groups].each { |dg| dg[:roles].clear } }, authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end
    end
  end

  as_a_project_deployer do
    describe 'a GET to #index' do
      before { current_release_count }

      it_responds_successfully do
        get :index, project_id: project.permalink
        assert_response_to_index(response)
      end
    end

    describe 'a POST to #create with a single role' do
      before do
        expect_file_contents_from_repo
        expect_deploy
        current_release_count
      end

      it_responds_successfully do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params, authenticity_token:  set_form_authenticity_token
        assert_response_to_create(response)
        assert_release_count(@current_release_count + 1)
      end
    end

    describe 'a POST to #create with multiple roles' do
      before do
        2.times { expect_file_contents_from_repo }
        expect_deploy
        current_release_count
      end

      it_responds_successfully do
        post :create, project_id: project.permalink, kubernetes_release: multiple_roles_release_params, authenticity_token:  set_form_authenticity_token
        assert_response_to_create(response)
        assert_release_count(@current_release_count + 1)
      end
    end

    describe 'a POST to #create with a missing build id' do
      before { current_release_count }

      it_responds_with_bad_request do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.except(:build_id), authenticity_token:  set_form_authenticity_token
        assert_response_with_errors(response)
        assert_release_count(@current_release_count)
      end
    end

    describe 'a POST to #create with missing deploy groups' do
      before { current_release_count }

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.except(:deploy_groups), authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.tap { |params| params[:deploy_groups].clear }, authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end
    end

    describe 'a POST to #create with missing roles' do
      before { current_release_count }

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.tap { |params| params[:deploy_groups].each { |dg| dg.delete(:roles) } }, authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end

      it_should_raise_an_exception do
        post :create, project_id: project.permalink, kubernetes_release: single_role_release_params.tap { |params| params[:deploy_groups].each { |dg| dg[:roles].clear } }, authenticity_token:  set_form_authenticity_token
        assert_release_count(@current_release_count)
      end
    end
  end

  #
  # Utility methods
  #

  def expect_deploy
    KuberDeployService.any_instance.expects(:deploy!)
  end

  def expect_file_contents_from_repo
    Build.any_instance.expects(:file_from_repo).returns(role_config_file)
  end

  def current_release_count
    @current_release_count = project.kubernetes_releases.count
  end

  def assert_response_to_index(response)
    result = JSON.parse(response.body)
    result.wont_be_nil
    result.wont_be_empty
    result.length.must_equal @current_release_count
    result.each do |release|
      release = Kubernetes::Release.find(release['id'])
      release.wont_be_nil
    end
  end

  def assert_response_to_create(response)
    result = JSON.parse(response.body)
    result.wont_be_nil
    result = result.with_indifferent_access
    result[:release][:build][:id].must_equal build.id
    result[:release][:user][:name].must_equal @controller.send(:current_user).name
    result[:release][:deploy_groups].size.must_equal 1
    result[:release][:deploy_groups][0][:id].must_equal deploy_group.id
    result[:release][:deploy_groups][0][:name].must_equal deploy_group.name
  end

  def assert_response_with_errors(response)
    result = JSON.parse(response.body)
    result.wont_be_nil
    result = result.with_indifferent_access
    result[:errors].wont_be_empty
  end

  def assert_release_count(current_count)
    project.kubernetes_releases.count.must_equal current_count
  end

  def single_role_release_params
    {
      build_id: build.id,
      deploy_groups: [
        {
          id: deploy_group.id,
          roles: [
            {
              id: app_server.id,
              replicas: 1
            }
          ]
        }
      ]
    }
  end

  def multiple_roles_release_params
    single_role_release_params.tap do |params|
      params[:deploy_groups].each do |dg|
        dg[:roles].push(id: resque_worker.id, replicas: 1)
      end
    end
  end
end
