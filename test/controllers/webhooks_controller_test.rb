# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe WebhooksController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:webhook) { project.webhooks.create!(stage: stage, branch: 'master', source: 'code') }

  as_a :viewer do
    unauthorized :post, :create, project_id: :foo
    unauthorized :delete, :destroy, project_id: :foo, id: 1

    describe '#index' do
      before { webhook } # trigger create

      it 'renders' do
        get :index, params: {project_id: project.to_param}
        assert_template :index
      end

      it "does not blow up with deleted stages" do
        stage.soft_delete!(validate: false)
        get :index, params: {project_id: project}
        assert_template :index
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
        flash[:alert].must_include 'branch'
        assert_template :index
        response.body.scan("<strong>#{params[:branch]}</strong>").count.must_equal 1 # do not show the built hook
      end
    end

    describe '#update' do
      let(:attributes) do
        {branch: 'my-branch', source: 'semaphore'}
      end

      it "updates the attributes and redirects" do
        patch :update, params: {project_id: project.to_param, id: webhook.to_param, webhook: attributes}
        webhook.reload
        refute flash[:alert]
        assert_redirected_to project_webhook_path(project, webhook)
        webhook.branch.must_equal 'my-branch'
        webhook.source.must_equal 'semaphore'
      end

      it "renders JSON" do
        patch :update, params: {project_id: project.to_param, id: webhook.to_param, webhook: attributes, format: :json}
        assert_response :success
        webhook = JSON.parse(response.body)['webhook']
        webhook['branch'].must_equal 'my-branch'
        webhook['source'].must_equal 'semaphore'
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
