# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::UsageLimitsController do
  let(:deploy_group) { deploy_groups(:pod100) }
  let(:project) { projects(:test) }
  let!(:usage_limit) { Kubernetes::UsageLimit.create!(scope: deploy_group, project: project, cpu: 1, memory: 10) }

  unauthorized :get, :index
  unauthorized :get, :show, id: 1

  as_a :deployer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :patch, :update, id: 1
    unauthorized :delete, :destroy, id: 1

    describe "#index" do
      let!(:other) { Kubernetes::UsageLimit.create!(cpu: 1, memory: 10, scope: environments(:staging)) }

      it "renders" do
        get :index
        assert_template :index
      end

      it "renders as project tab" do
        get :index, params: {project_id: project}
        assert_template :index
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [usage_limit.id]
      end

      it "can find by project" do
        get :index, params: {search: {project_id: usage_limit.project_id}}
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [usage_limit.id]
      end

      it "can find limits that apply to all projects" do
        get :index, params: {search: {project_id: 'all'}}
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [other.id]
      end

      it "can find by scope" do
        get :index, params: {search: {scope_type_and_id: "#{usage_limit.scope_type}-#{usage_limit.scope_id}"}}
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [usage_limit.id]
      end

      it "can find limits that apply to all scopes" do
        other.update_columns(scope_id: nil, scope_type: nil)
        get :index, params: {search: {scope_type_and_id: 'all'}}
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [other.id]
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: usage_limit.id}
        assert_template :show
      end
    end
  end

  as_a :admin do
    describe "#index" do
      let!(:other) { Kubernetes::UsageLimit.create!(cpu: 1, memory: 10, scope: environments(:production)) }

      it "renders" do
        get :index
        assert_template :index
      end

      it "can find by project" do
        get :index, params: {search: {project_id: usage_limit.project_id}}
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [usage_limit.id]
      end

      it "can find by scope" do
        get :index, params: {search: {scope_type_and_id: "#{usage_limit.scope_type}-#{usage_limit.scope_id}"}}
        assigns(:kubernetes_usage_limits).map(&:id).must_equal [usage_limit.id]
      end
    end

    describe "#new" do
      it "renders" do
        get :new
        assert_template :new
      end
    end

    describe "#create" do
      let(:params) { {cpu: 1, memory: 10, project_id: project.id, scope_type_and_id: "DeployGroup-#{deploy_group}"} }

      it "redirects on success" do
        post :create, params: {kubernetes_usage_limit: params}
        assert_redirected_to Kubernetes::UsageLimit.last
      end

      it "renders when it fails to create" do
        params.delete(:cpu)
        post :create, params: {kubernetes_usage_limit: params}
        assert_template :new
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: usage_limit.id}
        assert_template :show
      end
    end

    describe "#update" do
      it "updates" do
        patch :update, params: {id: usage_limit.id, kubernetes_usage_limit: {cpu: 2}}
        assert_redirected_to usage_limit
        usage_limit.reload.cpu.must_equal 2
      end

      it "shows errors when it fails to update" do
        patch :update, params: {id: usage_limit.id, kubernetes_usage_limit: {cpu: ""}}
        assert_template :edit
      end
    end

    describe "#destroy" do
      it "destroys" do
        assert_difference "Kubernetes::UsageLimit.count", -1 do
          delete :destroy, params: {id: usage_limit.id}
          assert_redirected_to "/kubernetes/usage_limits"
        end
      end
    end
  end
end
