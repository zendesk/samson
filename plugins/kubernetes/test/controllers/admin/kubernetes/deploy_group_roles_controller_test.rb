# frozen_string_literal: true
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
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
        assigns[:deploy_group_roles].must_include deploy_group_role
      end

      it "can filter by project_id" do
        deploy_group_role.update_column(:project_id, 123)
        get :index, params: {search: {project_id: project_id}}
        assigns[:deploy_group_roles].map(&:project_id).uniq.size.must_equal 1
      end

      it "can filter by deploy_group" do
        get :index, params: {search: {deploy_group_id: deploy_groups(:pod100).id}}
        assigns[:deploy_group_roles].map(&:deploy_group_id).uniq.size.must_equal 1
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: deploy_group_role.id}
        assert_template :show
      end
    end

    describe "#new" do
      it "renders" do
        get :new
        assert_template :new
      end

      it "can prefill" do
        get :new, params: {kubernetes_deploy_group_role: {kubernetes_role_id: kubernetes_roles(:app_server).id}}
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
            ram: 10,
            replicas: 1
          }
        }
      end

      it "can create for projects I am admin of" do
        post :create, params: params
        assert_redirected_to [:admin, Kubernetes::DeployGroupRole.last]
      end

      it "redirects to param" do
        post :create, params: params.merge(redirect_to: '/bar')
        assert_redirected_to '/bar'
      end

      it "renders when failing to create" do
        params[:kubernetes_deploy_group_role].delete(:cpu)
        post :create, params: params
        assert_template :new
      end

      it "cannot create for projects I am not admin of" do
        user.user_project_roles.delete_all
        post :create, params: params
        assert_response :unauthorized
      end
    end

    describe "#edit" do
      it "renders" do
        get :edit, params: {id: deploy_group_role.id}
        assert_template :edit
      end

      it "does not render when I am not admin" do
        user.user_project_roles.delete_all
        get :edit, params: {id: deploy_group_role.id}
        assert_response :unauthorized
      end
    end

    describe "#update" do
      let(:valid_params) { {id: deploy_group_role.id, kubernetes_deploy_group_role: {cpu: 3.1}} }

      it "updates" do
        put :update, params: valid_params
        deploy_group_role.reload.cpu.must_equal 3.1
        assert_redirected_to [:admin, deploy_group_role]
      end

      it "can redirect back" do
        valid_params[:redirect_to] = "/test"
        put :update, params: valid_params
        assert_redirected_to "/test"
      end

      it "does not allow to circumvent project admin protection" do
        put :update, params: {id: deploy_group_role.id, kubernetes_deploy_group_role: {project_id: 123}}
        deploy_group_role.reload.project_id.must_equal projects(:test).id
        assert_redirected_to [:admin, deploy_group_role]
      end

      it "does not allow updates for non-admins" do
        user.user_project_roles.delete_all
        put :update, params: valid_params
        assert_response :unauthorized
      end

      it "renders on failure" do
        put :update, params: {id: deploy_group_role.id, kubernetes_deploy_group_role: {cpu: ''}}
        assert_template :edit
      end
    end

    describe "#destroy" do
      it "deletes" do
        delete :destroy, params: {id: deploy_group_role.id}
        assert_raises(ActiveRecord::RecordNotFound) do
          deploy_group_role.reload
        end
      end

      it "does not delete when I am not an admin" do
        user.user_project_roles.delete_all
        delete :destroy, params: {id: deploy_group_role.id}
        assert deploy_group_role.reload
      end
    end

    describe "#seed" do
      it "adds missing roles" do
        Kubernetes::DeployGroupRole.expects(:seed!).returns true
        post :seed, params: {stage_id: stage.id}
        assert_redirected_to [stage.project, stage]
        assert flash[:notice]
      end

      it "fails to add missing roles" do
        Kubernetes::DeployGroupRole.expects(:seed!).returns false
        post :seed, params: {stage_id: stage.id}
        assert_redirected_to [stage.project, stage]
        assert flash[:alert]
      end
    end
  end
end
