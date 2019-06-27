# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ApplicationController do
  class ApplicationTestController < ApplicationController
    def test_render
      head :ok
    end

    def test_redirect_back
      redirect_back fallback_location: '/fallback', notice: params[:notice]
    end
  end

  tests ApplicationTestController
  use_test_routes ApplicationTestController

  describe "#redirect_back" do
    as_a :viewer do
      it "redirects to fallback" do
        get :test_redirect_back, params: {test_route: true}
        assert_redirected_to '/fallback'
      end

      it "redirects to redirect_to" do
        get :test_redirect_back, params: {test_route: true, redirect_to: '/param'}
        assert_redirected_to '/param'
      end

      it "redirects to redirect_to with query" do
        get :test_redirect_back, params: {test_route: true, redirect_to: '/param?x=1&y=2'}
        assert_redirected_to '/param?x=1&y=2'
      end

      it "ignores blank redirect_to which comes from forms blindly filling it" do
        get :test_redirect_back, params: {test_route: true, redirect_to: ''}
        assert_redirected_to '/fallback'
      end

      describe "with referer" do
        before { request.env['HTTP_REFERER'] = '/header' }

        it "redirects to referrer" do
          get :test_redirect_back, params: {test_route: true}
          assert_redirected_to '/header'
        end

        it "prefers params over headers" do
          get :test_redirect_back, params: {test_route: true, redirect_to: '/param'}
          assert_redirected_to '/param'
        end
      end

      it "does not redirect to hacky url in redirect_to which might have come in via referrer" do
        assert_raises do
          get :test_redirect_back, params: {test_route: true, redirect_to: 'http://hacks.com'}
        end.message.must_include "Invalid redirect_to parameter"
      end

      it "does not redirect to hacky hash in redirect_to" do
        assert_raises do
          get :test_redirect_back, params: {test_route: true, redirect_to: {host: 'hacks.com', path: 'bar'}}
        end.message.must_include "Invalid redirect_to parameter"
      end

      it "can set a notice" do
        get :test_redirect_back, params: {test_route: true, redirect_to: '/param', notice: "hello"}
        assert_redirected_to '/param'
        assert flash[:notice]
      end
    end
  end

  describe "#store_requested_oauth_scope" do
    it "stores the web-ui scope" do
      get :test_render, params: {test_route: true}
      request.env['requested_oauth_scopes'].must_equal ['default', 'application_test']
    end
  end

  describe "Samson::Hooks::UserError" do
    as_a :viewer do
      before do
        ApplicationTestController.any_instance.expects(:test_redirect_back).raises(Samson::Hooks::UserError, "Wut")
      end

      it "displays nice html message" do
        get :test_redirect_back, params: {test_route: true}
        assert_response :bad_request
        response.body.must_equal "Wut"
      end

      it "displays nice json message" do
        get :test_redirect_back, params: {test_route: true}, format: :json
        assert_response :bad_request
        response.body.must_equal "{\"status\":400,\"error\":\"Wut\"}"
      end
    end
  end

  describe "using_per_request_auth?" do
    it 'cannot POST without authenticity_token when warden was not used (for controller tests)' do
      request.env.delete 'warden'
      refute @controller.send(:using_per_request_auth?)
    end
  end
end

describe "ApplicationController Integration" do
  let(:user) { users(:super_admin) }
  let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default') }

  describe "#using_per_request_auth?" do
    let(:post_params) { {lock: {resource_id: nil, resource_type: nil}, format: :json} }

    with_forgery_protection

    it 'can POST without authenticity_token when logging in via per request doorkeeper auth' do
      post '/locks', params: post_params, headers: {'Authorization' => "Bearer #{token.token}"}
      assert_response :success
    end

    it 'does not authenticate twice' do
      ::Doorkeeper::OAuth::Token.expects(:authenticate).returns(token) # called inside of DoorkeeperStrategy
      post '/locks', params: post_params, headers: {'Authorization' => "Bearer #{token.token}"}
      assert_response :success
    end

    describe "when in the browser" do
      before { stub_session_auth }

      it 'can GET without authenticity_token' do
        get '/locks', params: {format: :json}
        assert_response :success
      end

      it 'cannot POST without authenticity_token' do
        post '/locks', params: post_params
        assert_response :unauthorized
      end
    end

    it 'cannot POST without authenticity_token when not logged in' do
      post '/locks', params: post_params
      assert_response :unauthorized
    end
  end
end
