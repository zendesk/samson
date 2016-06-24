require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::TasksController do
  let(:project) { task.project }
  let(:task) { kubernetes_tasks(:db_migrate) }
  let(:task_params) do
    {
      name: 'NAME',
      config_file: 'dsfsd.yml',
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
    end

    describe "#show" do
      it "renders" do
        get :show, project_id: project, id: task.id
        assert_template :show
      end
    end
  end

  as_a_project_admin do
    describe "#seed" do
      it "creates tasks" do
        Kubernetes::Task.expects(:seed!)
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
        post :create, project_id: project, kubernetes_task: task_params
        task = Kubernetes::Task.last
        assert_redirected_to "/projects/foo/kubernetes/tasks"
        task.name.must_equal 'NAME'
      end

      it "renders on failure" do
        task_params[:name] = ''
        post :create, project_id: project, kubernetes_task: task_params
        assert_template :new
      end
    end

    describe "#update" do
      it "updates" do
        put :update, project_id: project, id: task.id, kubernetes_task: task_params
        assert_redirected_to "/projects/foo/kubernetes/tasks"
        task.reload.name.must_equal 'NAME'
      end

      it "renders on failure" do
        task_params[:name] = ''
        put :update, project_id: project, id: task.id, kubernetes_task: task_params
        assert_template :show
      end
    end

    describe "#destroy" do
      it "destroys" do
        delete :destroy, project_id: project, id: task.id
        task.reload.deleted_at.wont_equal nil
        assert_redirected_to action: :index
      end
    end
  end
end
