# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 4

describe "JsonExceptions Integration" do
  describe "errors" do
    let(:user) { users(:super_admin) }
    let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: 'default') }

    def assert_json(code, message)
      assert_response code
      JSON.parse(response.body, symbolize_names: true).must_equal(status: code, error: message)
    end

    let(:headers) { {'Authorization' => "Bearer #{token.token}"} }

    # render exceptions like and no exception details like production
    around do |test|
      begin
        config = Rails.application.config
        old_show = config.action_dispatch.show_exceptions
        old_local = config.consider_all_requests_local
        config.action_dispatch.show_exceptions = true
        config.consider_all_requests_local = false
        test.call
      ensure
        config.action_dispatch.show_exceptions = old_show
        config.consider_all_requests_local = old_local
      end
    end

    before do
      stub_session_auth
      Airbrake.stubs(:build_notice) # prevent threadpool creation
    end

    it "presents validation errors" do
      # HACK: to deal with new controller implementation.
      # Ideally refactor this test to decouple from production code and use dummy controller/model
      lock_with_errors = Lock.new(warning: true, user: user)
      refute lock_with_errors.valid?
      Lock.any_instance.expects(:save!).raises(ActiveRecord::RecordInvalid.new(lock_with_errors))
      post '/locks.json', params: {lock: {warning: true}}, headers: headers
      assert_json 422, description: ["can't be blank"]
    end

    it "presents missing params errors" do
      post '/locks.json', params: {}, headers: headers
      assert_json 400, lock: ["is required"]
    end

    it "presents invalid keys errors" do
      post '/locks.json', params: {lock: {foo: :bar, baz: :bar}}, headers: headers
      assert_json 400, foo: ["is not permitted"], baz: ["is not permitted"]
    end

    it "presents unfound records" do
      delete '/locks/1.json', params: {id: 'does-not-exist'}, headers: headers
      assert_json 404, "Not Found"
    end

    it "presents random errors" do
      Lock.expects(:find).raises("Something bad")
      delete '/locks/1.json', params: {id: 1}, headers: headers
      assert_json 500, "Internal Server Error"
    end

    it "presents csrf errors" do
      with_forgery_protection do
        delete '/locks/1.json', params: {id: 1}
        assert_json 401, "Unauthorized"
      end
    end
  end
end
