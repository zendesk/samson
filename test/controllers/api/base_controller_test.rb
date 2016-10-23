# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BaseController do
  class ApiBaseTestController < Api::BaseController
    def test_render
      head :ok
    end

    private

    # turned off in test ... but we want to simulate it
    def allow_forgery_protection
      true
    end
  end

  tests ApiBaseTestController
  use_test_routes ApiBaseTestController

  describe "#paginate" do
    it 'paginates array' do
      @controller.send(:paginate, Array.new(1000).fill('a')).size.must_equal 1000
    end

    it 'paginates scope' do
      Deploy.stubs(:page).with(1).returns('foo')
      @controller.send(:paginate, Deploy).must_equal 'foo'
    end
  end

  describe "#current_project" do
    it "returns cached @project" do
      @controller.send(:current_project).must_equal nil
      @controller.instance_variable_set(:@project, 1)
      @controller.send(:current_project).must_equal 1
    end
  end

  describe "#using_per_request_auth?" do
    # cannot use login_as since setting the winning_strategy breaks regular auth
    before { request.env['warden'].set_user users(:admin) }

    it "allows posts without auth token for basic auth" do
      request.env['warden'].winning_strategy = :basic
      post :test_render, params: {test_route: true, format: :json}
      assert_response :success
    end

    it "allows posts without auth token for oauth auth" do
      request.env['warden'].winning_strategy = :doorkeeper
      post :test_render, params: {test_route: true, format: :json}
      assert_response :success
    end

    it "does not allows posts without auth token for sessions" do
      assert_raises ActionController::InvalidAuthenticityToken do
        post :test_render, params: {test_route: true, format: :json}
      end
    end
  end

  describe "#enforce_json_format" do
    it "fails without json" do
      get :test_render, params: {test_route: true}
      assert_response :unsupported_media_type
    end

    it "passes with json" do
      get :test_render, params: {test_route: true}, format: :json
      assert_response :unauthorized
    end

    it "does not pass with only json header" do
      json!
      get :test_render, params: {test_route: true}
      assert_response :unsupported_media_type
    end
  end
end
