# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe WebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:webhook) { project.webhooks.create!(stage: stage, branch: 'master', source: 'code') }

  # NOTE: here because messing with prepend-before-filters caused this even with authenticated users
  describe "when logged out" do
    it "redirects to login" do
      post :create, params: {project_id: project.to_param}
      assert_response :unauthorized
    end
  end

  as_a :viewer do
    unauthorized :post, :create, project_id: :foo
    unauthorized :put, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1

    describe '#index' do
      before { webhook } # trigger create

      it 'renders' do
        get :index, params: {project_id: project.to_param}
        assert_template :index
      end

      it 'renders json' do
        get :index, params: {project_id: project.to_param}, format: :json
        assert_response :success
      end

      it "does not blow up with deleted stages" do
        stage.soft_delete!(validate: false)
        get :index, params: {project_id: project}
        assert_template :index
      end
    end

    describe '#show' do
      it 'renders json' do
        get :show, params: {project_id: project.to_param, id: webhook.id, format: :json}
        assert_response :success
        assert_equal webhook.id, JSON.parse(response.body)["webhook"]["id"]
      end

      it 'returns 404 when webhook not found' do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project.to_param, id: 123456, format: :json}
        end
      end
    end
  end

  as_a :project_deployer do
    describe '#create' do
      let(:params) { {branch: "master", stage_id: stage.id, source: 'any'} }

      it "redirects to index" do
        post :create, params: {project_id: project.to_param, webhook: params}
        refute flash[:alert]
        assert_redirected_to project_webhooks_path(project)
      end

      it "shows validation errors" do
        webhook # already exists
        post :create, params: {project_id: project.to_param, webhook: params}
        assert flash[:alert]
        assert_template :index
      end
    end

    describe '#update' do
      it "updates" do
        put :update, params: {project_id: project.to_param, id: webhook.id, webhook: {branch: "foo"}}, format: :json
        assert_response :success
      end

      it "shows validation errors" do
        put :update, params: {project_id: project.to_param, id: webhook.id, webhook: {stage_id: nil}}, format: :json
        assert_response 422
      end
    end

    describe "#destroy" do
      it "deletes the hook" do
        delete :destroy, params: {project_id: project.to_param, id: webhook.id}
        assert_raises(ActiveRecord::RecordNotFound) { Webhook.find(webhook.id) }
        assert_redirected_to project_webhooks_path(project)
      end
    end
  end
end
