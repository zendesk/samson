require_relative '../test_helper'

describe WebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:user) { users(:admin) }

  setup do
    request.env['warden'].set_user(user)
  end

  describe 'GET :index' do
    it 'renders :index template' do
      get :index, project_id: project.to_param
      assert_template :index
    end
  end

  describe 'POST :create' do
    let(:params) { { branch: "master", stage_id: stage.id } }
    setup do
      post :create, project_id: project.to_param, webhook: params
    end

    describe 'with valid params' do
      it 'redirects to :index' do
        assert_redirected_to project_webhooks_path(project)
      end
      it 'creates a webhook' do
        project.reload
        assert project.webhooks.count, 1
        webhook = project.webhooks.first
        assert webhook.branch, params[:branch]
        assert webhook.stage, stage.name
      end
    end

    describe 'POST :delete' do
      setup do
        project.reload
        post :destroy, project_id: project.to_param, id: project.webhooks.first.id
        project.reload
      end
      it 'deletes the webhook' do
        assert project.webhooks.count, 0
      end
    end

    describe 'handles stage deletion' do
      setup do
        project.reload
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
