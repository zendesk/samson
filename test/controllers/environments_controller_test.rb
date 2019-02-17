# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe EnvironmentsController do
  let(:json) { JSON.parse(response.body) }

  as_a :viewer do
    describe "#index" do
      it 'renders' do
        get :index
        assert_response :success
        assert_select('tbody tr').count.must_equal Environment.count
      end

      it 'renders json' do
        get :index, format: 'json'
        json.keys.must_equal ['environments']
        json['environments'].count.must_equal Environment.count
      end

      it 'renders json with includes' do
        get :index, params: {includes: 'deploy_groups'}, format: 'json'
        json.keys.must_equal ['environments', 'deploy_groups']
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: environments(:production).id}
        assert_response :success
      end
    end

    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :delete, :destroy, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :put, :update, id: 1
  end

  as_a :super_admin do
    describe "#new" do
      it 'renders' do
        get :new
        assert_response :success
        assert assigns(:environment)
      end
    end

    describe '#create' do
      it 'creates an environment' do
        assert_difference 'Environment.count', +1 do
          post :create, params: {environment: {name: 'gamma', production: true}}
          assert_redirected_to "/environments/gamma"
        end
      end

      it 'does not create an environment with blank name' do
        env_count = Environment.count
        post :create, params: {environment: {name: nil, production: true}}
        assert_template :show
        Environment.count.must_equal env_count
      end
    end

    describe '#delete' do
      it 'succeeds' do
        env = environments(:production)
        delete :destroy, params: {id: env}
        assert_redirected_to environments_path
        Environment.where(id: env.id).must_equal []
      end

      it 'fail for non-existent environment' do
        assert_raises(ActiveRecord::RecordNotFound) do
          delete :destroy, params: {id: -1}
        end
      end
    end

    describe '#update' do
      let(:environment) { environments(:production) }

      before { request.env["HTTP_REFERER"] = environments_url }

      it 'save' do
        post :update, params: {environment: {name: 'Test Update', production: false, permalink: 'foo'}, id: environment}
        assert_redirected_to environments_path
        environment.reload
        environment.name.must_equal 'Test Update'
        environment.permalink.must_equal 'foo'
      end

      it 'fail to show with blank name' do
        post :update, params: {environment: {name: '', production: false}, id: environment}
        assert_template :show
        Environment.find(environment.id).name.must_equal 'Production'
      end
    end
  end
end
