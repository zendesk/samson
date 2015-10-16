require_relative '../test_helper'

describe WebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_deployer do
    describe 'GET :index' do
      it 'renders :index template' do
        get :index, project_id: project.to_param
        assert_template :index
      end
    end

    describe 'POST :create' do
      let(:params) { { branch: "master", stage_id: stage.id, source: 'any' } }
      setup do
        post :create, project_id: project.to_param, webhook: params
      end

      describe 'with valid params' do
        it 'redirects to :index' do
          assert_redirected_to project_webhooks_path(project)
        end
      end

      describe 'handles stage deletion' do
        setup do
          stage.soft_delete!
          project.reload
        end

        it "renders :index" do
          get :index, project_id: project.to_param
          assert_template :index
        end
      end
    end
  end

  as_a_project_deployer do
    describe 'GET :index' do
      it 'renders :index template' do
        get :index, project_id: project.to_param
        assert_template :index
      end
    end

    describe 'POST :create' do
      let(:params) { { branch: "master", stage_id: stage.id, source: 'any' } }
      setup do
        post :create, project_id: project.to_param, webhook: params
      end

      describe 'with valid params' do
        it 'redirects to :index' do
          assert_redirected_to project_webhooks_path(project)
        end
      end

      describe 'handles stage deletion' do
        setup do
          stage.soft_delete!
          project.reload
        end

        it "renders :index" do
          get :index, project_id: project.to_param
          assert_template :index
        end
      end
    end
  end


end
