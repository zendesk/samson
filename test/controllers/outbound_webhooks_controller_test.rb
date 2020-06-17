# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:params) { {url: "https://zendesk.com", auth_type: "None"} }
  let!(:webhook) { OutboundWebhook.create!(params.merge(stages: [stage])) }

  as_a :viewer do
    unauthorized :post, :create
    unauthorized :put, :update, id: 1
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :connect, id: 1

    describe "#index" do
      before { OutboundWebhook.create!(url: "http://something.else", auth_type: "None") }

      it "renders html" do
        get :index
        assert_response :success
      end

      it "renders json" do
        webhook.update!(username: "foo", password: "bar")
        get :index, format: :json
        assert_response :success
        hooks = JSON.parse(response.body).fetch("outbound_webhooks")
        hooks.size.must_equal 2
        json = hooks.detect { |h| h["id"] == webhook.id }
        json["username"].must_equal "foo"
        json.keys.wont_include "password"
      end

      it "can find for project" do
        get :index, params: {project_id: project}, format: :json
        assert_response :success
        JSON.parse(response.body).fetch("outbound_webhooks").size.must_equal 1
      end
    end
  end

  as_a :project_deployer do
    unauthorized :put, :update, id: 1
    unauthorized :put, :destroy, id: 1

    describe '#create' do
      it 'creates + links + redirects to :index' do
        assert_difference 'OutboundWebhook.count', 1 do
          assert_difference 'OutboundWebhookStage.count', 1 do
            post :create, params: {stage_id: stage.id, outbound_webhook: params}
            assert_redirected_to project_webhooks_path(project)
          end
        end
      end

      it 'can create via json' do
        post :create, params: {stage_id: stage.id, outbound_webhook: params}, format: :json
        assert_response :success
        outbound_webhook = JSON.parse(response.body)
        outbound_webhook['outbound_webhook']['url'].must_equal params[:url]
      end

      it 'shows errors to user when invalid' do
        assert_difference 'OutboundWebhook.count', 0 do
          params.merge!(auth_type: "Basic", username: 'foo')
          post :create, params: {stage_id: stage.id, outbound_webhook: params}
          flash[:alert].must_equal "Failed to create!"
          assert assigns[:resource] # for rendering errors
          assert_template 'webhooks/index' # form will display errors
        end
      end
    end

    describe "#destroy" do
      it "unlinks and destroys a stage hook" do
        assert_difference 'OutboundWebhook.count', -1 do
          assert_difference 'OutboundWebhookStage.count', -1 do
            delete :destroy, params: {id: webhook.id, stage_id: stage.id}
            assert_redirected_to project_webhooks_path(project)
          end
        end
      end

      it "unlinks from global" do
        webhook.update_column(:global, true)
        assert_difference 'OutboundWebhook.count', 0 do
          assert_difference 'OutboundWebhookStage.count', -1 do
            delete :destroy, params: {id: webhook.id, stage_id: stage.id}
            assert_redirected_to project_webhooks_path(project)
          end
        end
      end
    end

    describe "#connect" do
      it "can connect" do
        webhook.stages = []
        post :connect, params: {id: webhook.id, stage_id: stage.id}
        assert_redirected_to "/projects/foo/webhooks"
        webhook.reload.stages.size.must_equal 1
        assert flash[:notice]
      end

      it "shows error when duplicating" do
        post :connect, params: {id: webhook.id, stage_id: stage.id}
        assert_redirected_to "/projects/foo/webhooks"
        webhook.reload.stages.size.must_equal 1
        assert flash[:alert]
      end
    end
  end

  as_a :deployer do
    describe '#update' do
      it "updates" do
        patch :update, params: {id: webhook.id, outbound_webhook: params}
        assert_redirected_to "/outbound_webhooks"
      end

      it "fails to update" do
        params[:url] = ""
        patch :update, params: {id: webhook.id, outbound_webhook: params}
        assert_response :success
      end

      it "does remove stored password from rails not rendering the password fields value" do
        webhook.update_column(:password, 'b')
        patch :update, params: {id: webhook.id, outbound_webhook: {username: 'a', password: ''}}
        assert_response :redirect
        webhook.reload.password.must_equal 'b'
      end

      it "allows unsetting username/password by setting both blank" do
        webhook.update_column(:password, 'b')
        patch :update, params: {id: webhook.id, outbound_webhook: {username: '', password: ''}}
        assert_response :redirect
        webhook.reload.password.must_equal ''
      end

      it "updates via json" do
        patch :update, params: {id: webhook.id, outbound_webhook: params}, format: :json
        assert_response :success
        outbound_webhook = JSON.parse(response.body).fetch('outbound_webhook')
        outbound_webhook.fetch('url').must_equal params[:url]
      end

      it "fails to update via json" do
        params[:url] = ""
        patch :update, params: {id: webhook.id, outbound_webhook: params}, format: :json
        assert_response 422
      end
    end

    describe "#destroy" do
      it "deletes unused hook" do
        webhook.outbound_webhook_stages.destroy_all
        delete :destroy, params: {id: webhook.id}
        refute OutboundWebhook.find_by_id(webhook.id)
        assert_redirected_to "/outbound_webhooks"
      end

      it "refuses to delete used hook" do
        delete :destroy, params: {id: webhook.id}
        webhook.reload
        assert_redirected_to "/outbound_webhooks/#{webhook.id}"
      end
    end
  end
end
