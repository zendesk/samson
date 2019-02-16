# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:params) { {url: "https://zendesk.com", stage_id: stage.id} }
  let(:invalid_params) { {url: "https://zendesk.com", username: "poopthe@cat.com", stage_id: stage.id} }

  as_a :viewer do
    unauthorized :post, :create, project_id: :foo
    unauthorized :delete, :destroy, project_id: :foo, id: 1
  end

  as_a :project_deployer do
    describe '#create' do
      describe 'with valid params' do
        it 'redirects to :index' do
          assert_difference 'OutboundWebhook.count', 1 do
            post :create, params: {project_id: project.to_param, outbound_webhook: params}
            assert_redirected_to project_webhooks_path(project)
          end
        end

        it 'renders JSON' do
          post :create, params: {project_id: project.to_param, outbound_webhook: params}, format: :json
          assert_response :success
          outbound_webhook = JSON.parse(response.body)
          outbound_webhook['webhook']['url'].must_equal params[:url]
        end
      end

      describe 'with invalid params' do
        it 'renders to :index' do
          assert_difference 'OutboundWebhook.count', 0 do
            post :create, params: {project_id: project.to_param, outbound_webhook: invalid_params}
            assert_equal flash[:error], "Password can't be blank"
            assert_template 'webhooks/index'
          end
        end
      end
    end

    describe '#update' do
      let(:outbound_webhook) do
        project.outbound_webhooks.create!(stage: stage, url: 'http://old-url.com')
      end
      let(:params) do
        {
          project_id: project.to_param,
          id: outbound_webhook.to_param,
          outbound_webhook: {url: 'https://new-url.com'}
        }
      end

      it "updates the attributes and redirects" do
        patch :update, params: params
        outbound_webhook.reload
        refute flash[:alert]
        assert_redirected_to project_webhooks_path(project)
        outbound_webhook.url.must_equal params[:outbound_webhook][:url]
      end

      it "renders JSON" do
        patch :update, params: params, format: :json
        assert_response :success
        outbound_webhook = JSON.parse(response.body)['outbound_webhook']
        outbound_webhook['url'].must_equal params[:outbound_webhook][:url]
      end
    end

    describe "#destroy" do
      it "deletes the hook" do
        hook = project.outbound_webhooks.create!(params)
        delete :destroy, params: {project_id: project.to_param, id: hook.id}
        refute OutboundWebhook.find_by_id(hook.id)
        assert_redirected_to project_webhooks_path(project)
      end
    end
  end
end
