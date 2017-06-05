# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe "Api::BaseController Integration" do
  describe "errors" do
    let(:user) { users(:super_admin) }
    let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default') }

    def assert_json(code, message)
      assert_response code
      JSON.parse(response.body, symbolize_names: true).must_equal(status: code, error: message)
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
