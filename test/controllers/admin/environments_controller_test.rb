require_relative '../../test_helper'

describe Admin::EnvironmentsController do
  as_a_admin do
    it 'get index as admin succeeds' do
      get :index
      response.success?.must_equal true
      assigns(:environments).count.must_equal 2
    end

    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
  end

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
  end

  as_a_super_admin do
    it 'should create an environment' do
      post :create, environment: {name: 'gamma', is_production: true}
      assert_redirected_to admin_environments_path
      Environment.where(name: 'gamma').count.must_equal 1
    end

    it 'should delete an environment' do
      id = environments(:production_env).id
      delete :destroy, id: id
      assert_redirected_to admin_environments_path
      Environment.where(id: id).must_equal []
    end

    it 'should edit an environment' do
      id = environments(:production_env).id
      post :update, environment: {name: 'Test Update', is_production: false}, id: id
      assert_redirected_to admin_environments_path
      Environment.find(id).name.must_equal 'Test Update'
    end
  end
end
