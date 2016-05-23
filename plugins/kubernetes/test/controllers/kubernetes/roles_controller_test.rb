require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::RolesController do
  let(:project) { role.project }
  let(:role) { kubernetes_roles(:app_server) }
  let(:role_params) do
    {
      name: 'NAME',
      service_name: 'SERVICE_NAME',
      config_file: 'dsfsd.yml',
      deploy_strategy: 'RollingUpdate'
    }
  end

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :post, :seed, project_id: :foo
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :get, :show, project_id: :foo, id: 1
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_deployer do
    unauthorized :post, :seed, project_id: :foo
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1

    describe "#index" do
      it "renders" do
        get :index, project_id: project
        assert_template :index
      end

      it "can render as json" do
        get :index, project_id: project, format: 'json'
        JSON.parse(response.body).size.must_equal project.kubernetes_roles.size
      end
    end

    describe "#show" do
      it "renders" do
        get :show, project_id: project, id: role.id
        assert_template :show
      end
    end
  end

  as_a_project_admin do
    describe "#seed" do
      it "creates roles" do
        Kubernetes::Role.expects(:seed!)
        post :seed, project_id: project, ref: 'HEAD'
        assert_redirected_to action: :index
      end
    end

    describe "#new" do
      it "renders" do
        get :new, project_id: project
        assert_template :new
      end
    end

    describe "#create" do
      it "creates" do
        post :create, project_id: project, kubernetes_role: role_params
        role = Kubernetes::Role.last
        assert_redirected_to "/projects/foo/kubernetes/roles"
        role.name.must_equal 'NAME'
      end

      it "renders on failure" do
        role_params[:name] = ''
        post :create, project_id: project, kubernetes_role: role_params
        assert_template :new
      end
    end

    describe "#update" do
      it "updates" do
        put :update, project_id: project, id: role.id, kubernetes_role: role_params
        assert_redirected_to "/projects/foo/kubernetes/roles"
        role.reload.name.must_equal 'NAME'
      end

      it "renders on failure" do
        role_params[:name] = ''
        put :update, project_id: project, id: role.id, kubernetes_role: role_params
        assert_template :show
      end
    end

    describe "#destroy" do
      it "destroys" do
        delete :destroy, project_id: project, id: role.id
        role.reload.deleted_at.wont_equal nil
        assert_redirected_to action: :index
      end
    end
  end
end
