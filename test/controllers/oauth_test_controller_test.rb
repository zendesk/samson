# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OauthTestController do
  before { Doorkeeper::Application.create!(redirect_uri: 'http://test.host/oauth_test/token', name: 'test') }

  describe "#ensure_application" do
    it "renders instructions when app does not exist" do
      Doorkeeper::Application.delete_all
      get :index
      assert_response :success
      response.body.must_include 'Add an OAuth'
    end
  end

  describe "#index" do
    it "redirects to authorization url" do
      get :index
      assert_redirected_to %r{http://www.test-url.com/oauth/authorize}
    end
  end

  describe "#show" do
    it "shows my token" do
      get :show, params: {id: 'token', code: 'my-token'}
      assert_response :success
      response.body.must_include 'my-token'
    end
  end
end
