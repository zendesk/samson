require_relative '../test_helper'

SingleCov.covered!

describe WebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a_project_deployer do
    describe '#index' do
      it 'renders' do
        get :index, project_id: project.to_param
        assert_template :index
      end
    end

    describe '#create' do
      let(:params) { { branch: "master", stage_id: stage.id, source: 'any' } }

      before do
        post :create, project_id: project.to_param, webhook: params
      end

      describe 'with valid params' do
        it 'redirects to :index' do
          assert_redirected_to project_webhooks_path(project)
        end
      end

      describe 'handles stage deletion' do
        before do
          stage.soft_delete!
          project.reload
        end

        it "renders :index" do
          get :index, project_id: project.to_param
          assert_template :index
        end
      end
    end

    describe "#destroy" do
      it "deletes the hook" do
        hook = project.webhooks.create!(stage: stage, branch: 'master', source: 'code')
        delete :destroy, project_id: project.to_param, id: hook.id
        assert_raises(ActiveRecord::RecordNotFound) { Webhook.find(hook.id) }
        assert_redirected_to project_webhooks_path(project)
      end
    end
  end
end
