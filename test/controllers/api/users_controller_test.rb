# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::UsersController do
  oauth_setup!

  before { @request_format = :json }

  as_a_deployer do
    unauthorized :get, :show, id: 1, format: :json
    unauthorized :get, :show_via_resource, email: 'no-matter@example.com', format: :json
    unauthorized :delete, :destroy, id: 1, format: :json
  end

  as_an_admin do
    describe "#show" do
      it "shows" do
        get :show, params: {id: users(:admin)}, format: :json
        assert_response :success
      end
    end

    unauthorized :get, :show_via_resource, email: 'no-matter@example.com', format: :json
    unauthorized :delete, :destroy, id: 1, format: :json
  end

  as_a_super_admin do
    describe "#show" do
      it "shows" do
        get :show, params: {id: users(:admin)}, format: :json
        data = JSON.parse(response.body)

        assert_response :success
        assert_equal data['user']['id'], 135138680
      end
    end

    describe "#show_via_resource" do
      it "shows" do
        get :show_via_resource, params: {email: users(:admin).email}, format: :json
        data = JSON.parse(response.body)

        assert_response :success
        assert_equal data['user']['email'], 'admin@example.com'
      end
    end

    describe "#destroy" do
      it "deletes" do
        delete :destroy, params: {id: users(:admin)}, format: :json
        assert_response :success
        assert users(:admin).reload.deleted_at
      end
    end
  end
end
