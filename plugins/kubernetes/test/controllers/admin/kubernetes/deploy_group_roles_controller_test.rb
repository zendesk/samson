require_relative '../../../test_helper'

SingleCov.covered!

describe Admin::Kubernetes::DeployGroupRolesController do
  let(:deploy_group_role) { kubernetes_deploy_group_roles(:test_pod1_app_server) }
  let(:deploy_group) { deploy_group_role.deploy_group }
  let(:project) { deploy_group_role.project }
  let(:stage) { stages(:test_staging) }

  id = ActiveRecord::FixtureSet.identify(:test_pod1_app_server)
  project_id = ActiveRecord::FixtureSet.identify(:test)

  as_a_viewer do
    unauthorized :get, :index
    unauthorized :get, :new
    unauthorized :post, :create, kubernetes_deploy_group_role: {project_id: project_id}
    unauthorized :get, :show, id: id
    unauthorized :get, :edit, id: id
    unauthorized :get, :update, id: id
    unauthorized :get, :destroy, id: id
  end

  as_a_deployer do
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
      end
    end

    describe "#show" do
      it "renders" do
        get :show, id: deploy_group_role.id
        assert_template :show
      end
    end

    describe "#new" do
      it "renders" do
        get :new
        assert_template :new
      end

      it "can prefill" do
        get :new, kubernetes_deploy_group_role: {kubernetes_role_id: kubernetes_roles(:app_server).id}
        assert_template :new
        assigns(:deploy_group_role).kubernetes_role_id.must_equal kubernetes_roles(:app_server).id
      end
    end

    unauthorized :post, :create, kubernetes_deploy_group_role: {project_id: project_id}
    unauthorized :get, :edit, id: id
    unauthorized :get, :update, id: id
    unauthorized :get, :destroy, id: id
    unauthorized :post, :seed, stage_id: ActiveRecord::FixtureSet.identify(:test_staging)
  end

  as_a_project_admin do
    describe "#create" do
      let(:params) do
        {
          kubernetes_deploy_group_role: {
            project_id: project.id,
            kubernetes_role_id: kubernetes_roles(:app_server).id,
            deploy_group_id: deploy_group.id,
            cpu: 1,
            ram: 1,
            replicas: 1
          }
        }
      end

      it "can create for projects I am admin of" do
        post :create, params
        assert_redirected_to [:admin, Kubernetes::DeployGroupRole.last]
      end

      it "renders when failing to create" do
        params[:kubernetes_deploy_group_role].delete(:cpu)
        post :create, params
        assert_template :new
      end

      it "cannot create for projects I am not admin of" do
        user.user_project_roles.delete_all
        post :create, params
        assert_unauthorized
      end
    end

    describe "#edit" do
      it "renders" do
        get :edit, id: deploy_group_role.id
        assert_template :edit
      end

      it "does not render when I am not admin" do
        user.user_project_roles.delete_all
        get :edit, id: deploy_group_role.id
        assert_unauthorized
      end
    end

    describe "#update" do
      it "updates" do
        put :update, id: deploy_group_role.id, kubernetes_deploy_group_role: {cpu: 3.1}
        deploy_group_role.reload.cpu.must_equal 3.1
        assert_redirected_to [:admin, deploy_group_role]
      end

      it "does not allow to circumvent project admin protection" do
        put :update, id: deploy_group_role.id, kubernetes_deploy_group_role: {project_id: 123}
        deploy_group_role.reload.project_id.must_equal projects(:test).id
        assert_redirected_to [:admin, deploy_group_role]
      end

      it "does not allow updates for non-admins" do
        user.user_project_roles.delete_all
        put :update, id: deploy_group_role.id, kubernetes_deploy_group_role: {cpu: 3.1}
        assert_unauthorized
      end

      it "renders on failure" do
        put :update, id: deploy_group_role.id, kubernetes_deploy_group_role: {cpu: ''}
        assert_template :edit
      end
    end

    describe "#destroy" do
      it "deletes" do
        delete :destroy, id: deploy_group_role.id
        assert_raises(ActiveRecord::RecordNotFound) do
          deploy_group_role.reload
        end
      end

      it "does not delete when I am not an admin" do
        user.user_project_roles.delete_all
        delete :destroy, id: deploy_group_role.id
        assert deploy_group_role.reload
      end
    end

    describe "#seed" do
      it "adds missing roles" do
        Kubernetes::DeployGroupRole.expects(:seed!).returns true
        post :seed, stage_id: stage.id
        assert_redirected_to [stage.project, stage]
        assert flash[:notice]
      end

      it "fails to add missing roles" do
        Kubernetes::DeployGroupRole.expects(:seed!).returns false
        post :seed, stage_id: stage.id
        assert_redirected_to [stage.project, stage]
        assert flash[:alert]
      end
    end
  end
end
