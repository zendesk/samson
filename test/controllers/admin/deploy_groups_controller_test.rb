require_relative '../../test_helper'

describe Admin::DeployGroupsController do
  as_a_deployer do
    unauthorized :get, :index
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :get, :new
  end

  as_a_admin do
    it 'get index succeeds' do
      get :index
      response.success?.must_equal true
      assigns(:deploy_groups).count.must_equal 3
    end

    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :get, :new
  end

  as_a_super_admin do
    it 'get :index succeeds' do
      get :index
      response.success?.must_equal true
      assigns(:deploy_groups).count.must_equal 3
      deploy_groups = assigns(:deploy_groups)
      deploy_groups.include?(deploy_groups(:deploy_group_pod1)).must_equal true
      deploy_groups.include?(deploy_groups(:deploy_group_pod2)).must_equal true
      deploy_groups.include?(deploy_groups(:deploy_group_pod100)).must_equal true
    end

    it 'get :new succeeds' do
      get :new
      response.success?.must_equal true
      assigns(:deploy_group).wont_be_nil
    end

    describe '#create' do
      it 'valid deploy_group' do
        post :create, deploy_group: {name: 'pod666', environment_id: environments(:staging_env).id}
        assert_redirected_to admin_deploy_groups_path
        deploy_groups = DeployGroup.where(name: 'pod666')
        deploy_groups.count.must_equal 1
        deploy_groups.first.environment.name.must_equal 'Staging'
      end

      it 'should not create an deploy_group with blank name' do
        deploy_group_count = DeployGroup.count
        post :create, deploy_group: {name: nil}
        assert_redirected_to new_admin_deploy_group_path
        flash[:error].must_equal 'Failed to create deploy group: ["Name can\'t be blank", "Environment can\'t be blank"]'
        DeployGroup.count.must_equal deploy_group_count
      end
    end

    describe '#delete' do
      it 'success' do
        id = deploy_groups(:deploy_group_pod100).id
        delete :destroy, id: id
        assert_redirected_to admin_deploy_groups_path
        DeployGroup.where(id: id).must_equal []
      end

      it 'fail for non-existent deploy_group' do
        delete :destroy, id: -1
        assert_redirected_to admin_deploy_groups_path
        flash[:error].must_equal 'Failed to find the deploy group: -1'
      end
    end

    describe '#edit' do
      let(:deploy_group) { deploy_groups(:deploy_group_pod100) }

      before { request.env["HTTP_REFERER"] = admin_deploy_groups_url }

      it 'save' do
        post :update, deploy_group: {name: 'Test Update', environment_id: environments(:production_env)}, id: deploy_group.id
        assert_redirected_to admin_deploy_groups_path
        DeployGroup.find(deploy_group.id).name.must_equal 'Test Update'
      end

      it 'fail to edit with blank name' do
        post :update, deploy_group: {name: ''}, id: deploy_group.id
        assert_redirected_to admin_deploy_groups_path
        flash[:error].must_equal 'Failed to update deploy group: ["Name can\'t be blank"]'
        DeployGroup.find(deploy_group.id).name.must_equal 'Pod 100'
      end
    end
  end
end
