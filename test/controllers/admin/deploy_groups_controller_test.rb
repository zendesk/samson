require_relative '../../test_helper'

describe Admin::DeployGroupsController do
  as_a_admin do
    it 'get index as admin succeeds' do
      get :index
      response.success?.must_equal true
      assigns(:deploy_groups).count.must_equal 3
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
    before { request.env["HTTP_REFERER"] = admin_deploy_groups_url }

    it 'should create an environment' do
      post :create, deploy_group: {name: 'pod666', environment_id: environments(:staging_env).id}
      assert_redirected_to admin_deploy_groups_path
      deploy_groups = DeployGroup.where(name: 'pod666')
      deploy_groups.count.must_equal 1
      deploy_groups.first.environment.name.must_equal 'Staging'
    end

    it 'should delete an environment' do
      id = deploy_groups(:deploy_group_pod100).id
      delete :destroy, id: id
      assert_redirected_to admin_deploy_groups_path
      DeployGroup.where(id: id).must_equal []
    end

    it 'should edit an environment' do
      id = deploy_groups(:deploy_group_pod100).id
      post :update, deploy_group: {name: 'Test Update', environment_id: environments(:production_env)}, id: id
      assert_redirected_to admin_deploy_groups_path
      DeployGroup.find(id).name.must_equal 'Test Update'
    end
  end
end
