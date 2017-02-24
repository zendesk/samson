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
      I18n.expects(:t).with('doorkeeper.applications.help.scopes').returns('foo api_base_test')
      get :test_render, params: {test_route: true}, format: :json
      assert_response :unauthorized
      request.env['requested_oauth_scope'].must_equal 'api_base_test'
    end

    it "fails when scope is unknown" do
      e = assert_raises(RuntimeError) { get :test_render, params: {test_route: true}, format: :json }
      e.message.must_include "Add api_base_test to"
    end
  end
end

describe "Api::BaseController Integration" do
  describe "errors" do
    let(:user) { users(:super_admin) }
    let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default') }

    def assert_json(code, message)
      assert_response code
      JSON.parse(response.body, symbolize_names: true).must_equal(error: message)
    end

    let(:headers) { {'Authorization' => "Bearer #{token.token}"} }

    before do
      ActionDispatch::Request.any_instance.stubs(show_exceptions?: true) # render exceptions as production would
      stub_session_auth
    end

    it "presents validation errors" do
      post '/api/locks.json', params: {lock: {warning: true}}, headers: headers
      assert_json 422, description: ["can't be blank"]
    end

    it "presents missing params errors" do
      post '/api/locks.json', params: {}, headers: headers
      assert_json 400, lock: ["is required"]
    end

    it "presents invalid keys errors" do
      post '/api/locks.json', params: {lock: {foo: :bar, baz: :bar}}, headers: headers
      assert_json 400, foo: ["is not permitted"], baz: ["is not permitted"]
    end
  end
end
