require_relative '../../test_helper'

describe Admin::EnvironmentsController do
  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
  end

  as_a_admin do
    it 'get index as admin succeeds' do
      get :index
      assert_response :success
      envs = assigns(:environments)
      envs.include?(environments(:production_env)).must_equal true
      envs.include?(environments(:staging_env)).must_equal true
    end

    unauthorized :post, :create
    unauthorized :get, :new
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :put, :update, id: 1
  end

  as_a_super_admin do
    it 'get :index succeeds' do
      get :index
      assert_response :success
      assert_select('tbody tr').count.must_equal Environment.count
    end

    it 'get :new succeeds' do
      get :new
      assert_response :success
      assert assigns(:environment)
    end

    describe '#create' do
      it 'creates an environment' do
        post :create, environment: {name: 'gamma', is_production: true}
        assert_redirected_to admin_environments_path
        Environment.where(name: 'gamma').count.must_equal 1
      end

      it 'should not create an environment with blank name' do
        env_count = Environment.count
        post :create, environment: {name: nil, is_production: true}
        assert_template :new
        flash[:error].must_equal 'Failed to create environment: ["Name can\'t be blank"]'
        Environment.count.must_equal env_count
      end
    end

    describe '#delete' do
      it 'succeeds' do
        id = environments(:production_env).id
        delete :destroy, id: id
        assert_redirected_to admin_environments_path
        Environment.where(id: id).must_equal []
      end

      it 'fail for non-existent environment' do
        delete :destroy, id: -1
        assert_redirected_to admin_environments_path
        flash[:error].must_equal 'Failed to find the environment: -1'
      end
    end

    describe '#update' do
      let(:environment){ environments(:production_env) }

      before { request.env["HTTP_REFERER"] = admin_environments_url }

      it 'save' do
        post :update, environment: {name: 'Test Update', is_production: false}, id: environment.id
        assert_redirected_to admin_environments_path
        Environment.find(environment.id).name.must_equal 'Test Update'
      end

      it 'fail to edit with blank name' do
        post :update, environment: {name: '', is_production: false}, id: environment.id
        assert_template :edit
        flash[:error].must_equal 'Failed to update environment: ["Name can\'t be blank"]'
        Environment.find(environment.id).name.must_equal 'Production'
      end
    end
  end
end
