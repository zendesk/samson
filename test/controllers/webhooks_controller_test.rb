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
