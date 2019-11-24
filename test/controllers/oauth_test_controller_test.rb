# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OauthTestController do
  let!(:application) do
    Doorkeeper::Application.create!(
      secret: 'foo',
      uid: 'bar',
      redirect_uri: 'http://test.host/oauth_test/token',
      name: 'test'
    )
  end

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
      OAuth2::Strategy::AuthCode.any_instance.expects(:get_token).returns(stub(token: "some-token"))
      get :show, params: {id: 'token', code: 'my-code'}
      assert_response :success
      response.body.must_include "some-token"
    end

    it "redirects to the app when token is expired" do
      OAuth2::Strategy::AuthCode.any_instance.expects(:get_token).raises(
        OAuth2::Error.new(stub("error=": 1, parsed: nil, body: "B"))
      )
      get :show, params: {id: 'token', code: 'my-code'}
      assert_redirected_to "/oauth/applications/#{application.id}"
    end
  end
end
