require_relative '../test_helper'

describe KubernetesRolesController do

  let(:project) { projects(:test) }

  describe 'a GET to #index' do
    as_a_viewer do
      unauthorized :get, :index, project_id: :foo
    end

    as_a_deployer do
      it 'responds successfully' do
        get :index, project_id: :foo
        assert_response_body(response.body)
      end
    end

    as_a_project_deployer do
      it 'responds successfully' do
        get :index, project_id: :foo
        assert_response_body(response.body)
      end
    end

    def assert_response_body(response_body)
      roles = project.roles
      result = JSON.parse(response_body)
      result.wont_be_nil
      result.wont_be_empty
      result.length.must_equal roles.size
      result.each do |role|
        role_info = Kubernetes::Role.find(role['id'])
        role_info.wont_be_nil
      end
    end
  end

  describe 'a GET to #show' do
    let(:role) { kubernetes_roles(:app_server) }

    as_a_viewer do
      it 'responds with unauthorized' do
        get :show, project_id: :foo, id: role.id
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_deployer do
      it 'responds with unauthorized' do
        get :show, project_id: :foo, id: role.id
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_project_deployer do
      it 'responds with unauthorized' do
        get :show, project_id: :foo, id: role.id
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_admin do
      it 'responds successfully' do
        get :show, project_id: :foo, id: role.id
        assert_response_body(response.body)
      end
    end

    as_a_project_admin do
      it 'responds successfully' do
        get :show, project_id: :foo, id: role.id
        assert_response_body(response.body)
      end
    end

    def assert_response_body(response_body)
      result = JSON.parse(response_body)
      result.wont_be_nil
      result['id'].must_equal role.id
      result['name'].must_equal role.name
      result['replicas'].must_equal role.replicas
      result['ram'].must_equal role.ram
      result['cpu'].must_equal role.cpu.to_s
      result['deploy_strategy'].must_equal role.deploy_strategy
    end
  end

  describe 'a PUT to #update' do
    let(:role) { kubernetes_roles(:app_server) }

    as_a_viewer do
      it 'responds with unauthorized' do
        put :update, project_id: :foo, id: role.id, authenticity_token:  set_form_authenticity_token
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_deployer do
      it 'responds with unauthorized' do
        put :update, project_id: project.id, id: role.id, authenticity_token:  set_form_authenticity_token
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_project_deployer do
      it 'responds with unauthorized' do
        put :update, project_id: project.id, id: role.id, authenticity_token:  set_form_authenticity_token
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_admin do
      it 'responds successfully' do
        put :update, project_id: project.id, id: role.id, kubernetes_role: { replicas: 4, cpu: 1, ram: 512 }, authenticity_token:  set_form_authenticity_token
        assert_updated_role
        assert_response_body(response.body)
      end
    end

    as_a_project_admin do
      it 'responds successfully' do
        put :update, project_id: project.id, id: role.id, kubernetes_role: { replicas: 4, cpu: 1, ram: 512 }, authenticity_token:  set_form_authenticity_token
        assert_updated_role
        assert_response_body(response.body)
      end
    end

    def assert_updated_role
      role.reload
      role.name.wont_be_nil
      role.replicas.must_equal 4
      role.ram.must_equal 512
      role.cpu.must_equal 1
      role.deploy_strategy.wont_be_nil
    end

    def assert_response_body(response_body)
      result = JSON.parse(response_body)
      result.wont_be_nil
      result['id'].must_equal role.id
      result['name'].must_equal role.name
      result['replicas'].must_equal role.replicas
      result['ram'].must_equal role.ram
      result['cpu'].must_equal role.cpu.to_s
      result['deploy_strategy'].must_equal role.deploy_strategy
    end
  end

  describe 'a PUT to #update' do
    let(:role) { kubernetes_roles(:app_server) }

    as_a_viewer do
      it 'responds with unauthorized' do
        put :update, project_id: :foo, id: role.id, authenticity_token:  set_form_authenticity_token
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_deployer do
      it 'responds with unauthorized' do
        put :update, project_id: project.id, id: role.id, authenticity_token:  set_form_authenticity_token
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_project_deployer do
      it 'responds with unauthorized' do
        put :update, project_id: project.id, id: role.id, authenticity_token:  set_form_authenticity_token
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_admin do
      it 'responds successfully' do
        put :update, project_id: project.id, id: role.id, kubernetes_role: { replicas: 4, cpu: 1, ram: 512 }, authenticity_token:  set_form_authenticity_token
        assert_updated_role
        assert_response_body(response.body)
      end
    end

    as_a_project_admin do
      it 'responds successfully' do
        put :update, project_id: project.id, id: role.id, kubernetes_role: { replicas: 4, cpu: 1, ram: 512 }, authenticity_token:  set_form_authenticity_token
        assert_updated_role
        assert_response_body(response.body)
      end
    end

    as_a_admin do
      it 'returns user friendly errors as a result of a bad request' do
        put :update, project_id: project.id, id: role.id, kubernetes_role: { replicas: 0, cpu: 0, ram: 0 }, authenticity_token:  set_form_authenticity_token
        assert_role_not_updated
        assert_errors(response.body)
      end
    end

    def assert_updated_role
      role.reload
      role.name.wont_be_nil
      role.replicas.must_equal 4
      role.ram.must_equal 512
      role.cpu.must_equal 1
      role.deploy_strategy.wont_be_nil
    end

    def assert_role_not_updated
      role.reload
      role.replicas.must_equal 3
      role.ram.must_equal 1024
      role.cpu.must_equal 0.5
    end

    def assert_response_body(response_body)
      result = JSON.parse(response_body)
      result.wont_be_nil
      result['id'].must_equal role.id
      result['name'].must_equal role.name
      result['replicas'].must_equal role.replicas
      result['ram'].must_equal role.ram
      result['cpu'].must_equal role.cpu.to_s
      result['deploy_strategy'].must_equal role.deploy_strategy
    end

    def assert_errors(response_body)
      result = JSON.parse(response_body)
      result.wont_be_nil
      result['errors'].wont_be_nil
      result['errors'].wont_be_empty
      result['errors'].size.must_equal 3
      result['errors'].must_include 'Cpu must be greater than 0'
      result['errors'].must_include 'Ram must be greater than 0'
      result['errors'].must_include 'Replicas must be greater than 0'
    end
  end

  describe 'a GET to #refresh' do
    let(:role) { kubernetes_roles(:app_server) }
    let(:contents) { parse_role_config_file('kubernetes_role_config_file') }

    before do
      Project.any_instance.stubs(:directory_contents_from_repo).returns(['some_folder/file_name.yml'])
      Project.any_instance.stubs(:file_from_repo).returns(contents)
    end

    as_a_viewer do
      it 'responds with unauthorized' do
        get :refresh, project_id: :foo
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_deployer do
      it 'responds with unauthorized' do
        get :refresh, project_id: project.id
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_project_deployer do
      it 'responds with unauthorized' do
        get :refresh, project_id: project.id
        @unauthorized.must_equal true, 'Request should get unauthorized'
      end
    end

    as_a_admin do
      it 'responds successfully' do
        get :refresh, project_id: project.id, ref: 'some-ref'
        assert_new_roles
        assert_response_body(response.body)
      end
    end

    as_a_project_admin do
      it 'responds successfully' do
        get :refresh, project_id: project.id, ref: 'some-ref'
        assert_new_roles
        assert_response_body(response.body)
      end
    end

    as_a_admin do
      before do
        Project.any_instance.stubs(:directory_contents_from_repo).returns([])
      end

      it 'responds with a 404 if no config files where found' do
        get :refresh, project_id: project.id, ref: 'some-ref'
        assert_response :not_found
      end
    end

    def assert_new_roles
      project.roles.count.must_equal 1
      role = project.roles.first
      role.name.must_equal 'some-role'
      role.config_file.must_equal 'some_folder/file_name.yml'
      role.replicas.must_equal 2
      role.ram.must_equal 100
      role.cpu.must_equal 0.5
      role.deploy_strategy.must_equal 'RollingUpdate'
    end

    def assert_response_body(response_body)
      result = JSON.parse(response_body)
      result.wont_be_nil
      result.wont_be_empty
      result.length.must_equal project.roles.count
      result.each do |role|
        role_info = Kubernetes::Role.find(role['id'])
        role_info.wont_be_nil
      end
    end
  end
end
