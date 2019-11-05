# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:params) { {url: "https://zendesk.com", stage_id: stage.id} }
  let(:invalid_params) { {url: "https://zendesk.com", username: "poopthe@cat.com", stage_id: stage.id} }
  let(:webhook) { project.outbound_webhooks.create!(params) }

  as_a :viewer do
    unauthorized :post, :create, project_id: :foo
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1

    describe "#index" do
      it "renders json" do
        webhook.update!(username: "foo", password: "bar")
        get :index, params: {project_id: project}, format: :json
        assert_response :success
        json = JSON.parse(response.body).fetch("webhooks").fetch(0)
        json["username"].must_equal "foo"
        json.keys.wont_include "password"
      end
    end
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
          outbound_webhook['outbound_webhook']['url'].must_equal params[:url]
        end
      end

      describe 'with invalid params' do
        it 'renders to :index' do
          assert_difference 'OutboundWebhook.count', 0 do
            post :create, params: {project_id: project.to_param, outbound_webhook: invalid_params}
            assert_equal flash[:alert], "Failed to create!"
            assert assigns[:resource] # for rendering errors
            assert_template 'webhooks/index'
          end
        end
      end
    end

    describe '#update' do
      it "fails to update" do
        webhook
        params[:url] = ""
        patch :update, params: {id: webhook.id, project_id: project, outbound_webhook: params}, format: :json
        assert_response 422
      end

      it "renders JSON" do
        patch :update, params: {id: webhook.id, project_id: project, outbound_webhook: params}, format: :json
        assert_response :success
        outbound_webhook = JSON.parse(response.body).fetch('outbound_webhook')
        outbound_webhook.fetch('url').must_equal params[:url]
      end
    end

    describe "#destroy" do
      it "deletes the hook" do
        delete :destroy, params: {project_id: project.to_param, id: webhook.id}
        refute OutboundWebhook.find_by_id(webhook.id)
        assert_redirected_to project_webhooks_path(project)
      end
    end
  end
end
