require_relative '../../test_helper'

describe Admin::DeployGroupsController do
  def self.it_renders_index
    it 'get :index succeeds' do
      get :index
      assert_response :success
      assert_template :index
      assert_select('tbody tr').count.must_equal DeployGroup.count
    end
  end

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :get, :new
  end

  as_a_admin do
    it_renders_index
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :get, :new
  end

  as_a_super_admin do
    it_renders_index

    it 'get :new succeeds' do
      get :new
      assert_response :success
      assert assigns(:deploy_group)
    end

    describe '#create' do
      it 'creates a deploy group' do
        assert_difference 'DeployGroup.count', +1 do
          post :create, deploy_group: {name: 'pod666', environment_id: environments(:staging).id}
          assert_redirected_to admin_deploy_groups_path
        end
      end

      it 'fails with blank name' do
        deploy_group_count = DeployGroup.count
        post :create, deploy_group: {name: nil}
        assert_template :edit
        flash[:error].must_equal ["Name can't be blank", "Environment can't be blank"]
        DeployGroup.count.must_equal deploy_group_count
      end
    end

    describe '#delete' do
      it 'succeeds' do
        id = deploy_groups(:pod100).id
        delete :destroy, id: id
        assert_redirected_to admin_deploy_groups_path
        DeployGroup.where(id: id).must_equal []
      end

      it 'fails for non-existent deploy_group' do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, id: -1
        end
      end
    end

    describe '#update' do
      let(:deploy_group) { deploy_groups(:pod100) }

      before { request.env["HTTP_REFERER"] = admin_deploy_groups_url }

      it 'save' do
        post :update, deploy_group: {name: 'Test Update', environment_id: environments(:production)}, id: deploy_group.id
        assert_redirected_to admin_deploy_groups_path
        DeployGroup.find(deploy_group.id).name.must_equal 'Test Update'
      end

      it 'fail to edit with blank name' do
        post :update, deploy_group: {name: ''}, id: deploy_group.id
        assert_template :edit
        flash[:error].must_equal ["Name can't be blank"]
        DeployGroup.find(deploy_group.id).name.must_equal 'Pod 100'
      end
    end
  end
end
