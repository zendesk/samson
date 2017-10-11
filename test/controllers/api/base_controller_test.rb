# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::BaseController do
  class ApiBaseTestController < Api::BaseController
    def test_render
      head :ok
    end
  end

  tests ApiBaseTestController
  use_test_routes ApiBaseTestController
  with_forgery_protection

  before { @controller.stubs(:store_requested_oauth_scope) }

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
      @controller.send(:current_project).must_be_nil
      @controller.instance_variable_set(:@project, 1)
      @controller.send(:current_project).must_equal 1
    end
  end

  describe "#require_project" do
    it "finds a project" do
      @controller.params[:project_id] = projects(:test).id
      @controller.send(:require_project).must_equal projects(:test)
    end

    it "ignores missing project_id" do
      @controller.send(:require_project).must_be_nil
    end

    it "fails on invalid project" do
      @controller.params[:project_id] = 123
      assert_raises ActiveRecord::RecordNotFound do
        @controller.send(:require_project)
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

  describe "#store_requested_oauth_scope" do
    before { @controller.unstub(:store_requested_oauth_scope) }

    it "stores the controller scope" do
      get :test_render, params: {test_route: true}, format: :json
      assert_response :unauthorized
      request.env['requested_oauth_scopes'].must_equal ['default', 'api_base_test', 'api']
    end
  end
end
