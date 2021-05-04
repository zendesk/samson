# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::DeployGroupRolesController do
  let(:deploy_group_role) { kubernetes_deploy_group_roles(:test_pod1_app_server) }
  let(:deploy_group) { deploy_group_role.deploy_group }
  let(:project) { deploy_group_role.project }
  let(:stage) { stages(:test_staging) }

  id = ActiveRecord::FixtureSet.identify(:test_pod1_app_server)
  project_id = ActiveRecord::FixtureSet.identify(:test)

  as_a :viewer do
    describe "#index" do
      before do
        # one different to test filtering
        kubernetes_deploy_group_roles(:test_pod1_resque_worker).update_column(:project_id, projects(:other).id)
      end

      it "renders" do
        get :index
        assert_template :index
        assigns[:kubernetes_deploy_group_roles].must_include deploy_group_role
        assert assigns[:pagy]
      end

      it "renders when deploy group got deleted" do
        kubernetes_release_docs(:test_release_pod_1).deploy_group.update_column(:deleted_at, Time.now)
        get :index
        assert_template :index
      end

      it "renders as project tab" do
        get :index, params: {project_id: project}
        assert_template :index
        assigns[:kubernetes_deploy_group_roles].map(&:project_id).uniq.must_equal [project.id]
        refute assigns[:pagy]
      end

      it "paginates json project search" do
        get :index, params: {project_id: project}, format: :json
        assert assigns[:pagy]
      end

      it "can filter by project_id" do
        get :index, params: {search: {project_id: project.id}}
        assigns[:kubernetes_deploy_group_roles].map(&:project_id).uniq.must_equal [project.id]
      end

      it "can filter by deploy_group" do
        get :index, params: {search: {deploy_group_id: deploy_groups(:pod100).id}}
        assigns[:kubernetes_deploy_group_roles].map(&:deploy_group_id).uniq.must_equal [deploy_groups(:pod100).id]
      end
    end

    describe "#show" do
      let(:params) { {project_id: project, id: deploy_group_role.id} }

      it "renders" do
        get :show, params: params
        assert_template :show
      end
    end

    describe "#new" do
      it "renders" do
        get :new, params: {project_id: project}
        assert_template :new
      end

      it "can prefill" do
        attributes = {kubernetes_role_id: kubernetes_roles(:app_server).id}
        get :new, params: {project_id: project, kubernetes_deploy_group_role: attributes}
        assert_template :new, params: {project_id: project}
        assigns(:kubernetes_deploy_group_role).kubernetes_role_id.must_equal kubernetes_roles(:app_server).id
      end
    end

    unauthorized :post, :create, project_id: project_id
    unauthorized :get, :edit, id: id, project_id: project_id
    unauthorized :get, :update, id: id, project_id: project_id
    unauthorized :get, :destroy, id: id, project_id: project_id
    unauthorized :post, :seed, project_id: project_id, stage_id: ActiveRecord::FixtureSet.identify(:test_staging)
    unauthorized :get, :edit_many, project_id: project_id
    unauthorized :put, :update_many, project_id: project_id
  end

  as_a :project_admin do
    describe "#create" do
      let(:params) do
        {
          project_id: project,
          kubernetes_deploy_group_role: {
            kubernetes_role_id: kubernetes_roles(:app_server).id,
            deploy_group_id: deploy_group.id,
            requests_cpu: 0.5,
            requests_memory: 7,
            limits_cpu: 1,
            limits_memory: 10,
            replicas: 1
          }
        }
      end

      it "can create for projects I am admin of" do
        deploy_group_role.destroy!
        post :create, params: params
        assert_redirected_to [project, Kubernetes::DeployGroupRole.last]
      end

      it "redirects to param" do
        deploy_group_role.destroy!
        post :create, params: params.merge(redirect_to: '/bar')
        assert_redirected_to '/bar'
      end

      it "renders when failing to create" do
        params[:kubernetes_deploy_group_role].delete(:limits_cpu)
        post :create, params: params
        assert_template :new
      end

      it "cannot create for projects I am not admin of" do
        user.user_project_roles.delete_all
        post :create, params: params
        assert_response :unauthorized
      end

      describe "with no_cpu_limit" do
        before do
          deploy_group_role.destroy!
          params[:kubernetes_deploy_group_role][:no_cpu_limit] = 'true'
        end

        it "cannot assign" do
          assert_raises ActionController::UnpermittedParameters do
            post :create, params: params
          end
        end

        it "can assign when enabled" do
          stub_const Kubernetes::DeployGroupRole, :NO_CPU_LIMIT_ALLOWED, true do
            post :create, params: params
            assert_response :redirect
            assert Kubernetes::DeployGroupRole.last.no_cpu_limit
          end
        end
      end
    end

    describe "#edit" do
      it "renders" do
        get :edit, params: {project_id: project, id: deploy_group_role.id}
        assert_template :edit
      end
    end

    describe "#update" do
      let(:params) { {id: deploy_group_role.id, project_id: project, kubernetes_deploy_group_role: {limits_cpu: 0.7}} }

      it "updates" do
        put :update, params: params
        deploy_group_role.reload.limits_cpu.must_equal 0.7
        assert_redirected_to [project, deploy_group_role]
      end

      it "can redirect back" do
        params[:redirect_to] = "/test"
        put :update, params: params
        assert_redirected_to "/test"
      end

      it "does not allow to circumvent project admin protection" do
        params[:kubernetes_deploy_group_role][:project_id] = 123
        assert_raises ActionController::UnpermittedParameters do
          put :update, params: params
        end
      end

      it "does not allow updates for non-admins" do
        user.user_project_roles.delete_all
        put :update, params: params
        assert_response :unauthorized
      end

      it "renders on failure" do
        params[:kubernetes_deploy_group_role][:limits_cpu] = ''
        put :update, params: params
        assert_template :edit
      end
    end

    describe "#destroy" do
      it "deletes" do
        delete :destroy, params: {project_id: project, id: deploy_group_role.id}
        assert_raises(ActiveRecord::RecordNotFound) do
          deploy_group_role.reload
        end
      end

      it "does not delete when I am not an admin" do
        user.user_project_roles.delete_all
        delete :destroy, params: {project_id: project, id: deploy_group_role.id}
        assert deploy_group_role.reload
      end
    end

    describe "#seed" do
      it "adds missing roles" do
        post :seed, params: {project_id: project, stage_id: stage.id}
        assert_redirected_to [stage.project, stage]
        assert flash[:notice]
      end

      it "fails to add missing roles" do
        deploy_group_role.errors.add :base, 'foo'
        deploy_group_role.stubs(persisted?: false)
        Kubernetes::DeployGroupRole.expects(:seed!).returns [deploy_group_role]
        post :seed, params: {project_id: project, stage_id: stage.id}

        assert_redirected_to [stage.project, stage]
        error = flash[:alert]
        error.must_equal "<p>Roles failed to seed, fill them in manually.\n<br />app-server for Pod1: foo</p>"
        assert error.html_safe?
      end

      it "does not overflow cookies when trying to seed too many roles that all fail because of limit violations" do
        deploy_group_role.errors.add :base, 'foo'
        deploy_group_role.stubs(persisted?: false)
        Kubernetes::DeployGroupRole.expects(:seed!).returns Array.new(10).fill(deploy_group_role)
        post :seed, params: {project_id: project, stage_id: stage.id}
        flash[:alert].scan("app-server for Pod1").size.must_equal 3
      end
    end

    describe "#edit_many" do
      it "renders" do
        get :edit_many, params: {project_id: project}
        assert_template :edit_many
      end
    end

    describe "#update_many" do
      let(:other) { kubernetes_deploy_group_roles(:test_pod1_resque_worker) }

      before do
        # controller expects all roles to be sent in, so we remove the ones we don't intend to update
        Kubernetes::DeployGroupRole.where.not(id: [other.id, deploy_group_role.id]).delete_all
      end

      it "updates" do
        put :update_many, params: {
          project_id: project, kubernetes_deploy_group_roles: {
            deploy_group_role.id.to_s => {replicas: 5},
            other.id.to_s => {replicas: 1}
          }
        }
        assert_redirected_to project_kubernetes_deploy_group_roles_path(project)
        deploy_group_role.reload.replicas.must_equal 5
      end

      it "updates partially and renders errors when some fail" do
        put :update_many, params: {
          project_id: project,
          kubernetes_deploy_group_roles: {
            deploy_group_role.id.to_s => {replicas: 5},
            other.id.to_s => {requests_memory: 0}
          }
        }
        assert_template :edit_many
        deploy_group_role.reload.replicas.must_equal 5
      end

      it "shows failed updates" do
        put :update_many, params: {
          project_id: project,
          kubernetes_deploy_group_roles: {
            deploy_group_role.id.to_s => {requests_memory: 0},
            other.id.to_s => {replicas: 1}
          }
        }
        assert_template :edit_many
      end
    end
  end
end
