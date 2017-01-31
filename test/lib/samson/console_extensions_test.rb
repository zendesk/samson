# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ConsoleExtensions do
  include Samson::ConsoleExtensions

  with_forgery_protection

  describe "#login" do
    class ConsoleExtensionTestController < ApplicationController
      include CurrentUser
      before_action :authorize_super_admin!

      def secret
        render plain: 'OK'
      end
    end

    def call_action
      status, _headers, body = ConsoleExtensionTestController.action(:secret).call(request)
      status.must_equal 200
      body.body.to_s.must_equal 'OK'
    end

    let(:request) { {'rack.input' => StringIO.new, 'REQUEST_METHOD' => 'GET'} }
    let(:user) { users(:super_admin) }

    # modify our fake class and not the original to not break all other tests
    before { Samson::ConsoleExtensions.const_set(:CurrentUser, ConsoleExtensionTestController) }
    after { Samson::ConsoleExtensions.send(:remove_const, :CurrentUser) }

    # we are not going through the middleware, so there is no warden
    before do
      ConsoleExtensionTestController.any_instance.stubs(warden: stub(winning_strategy: nil))
    end

    it "sets user to given user" do
      login(user)
      ConsoleExtensionTestController.new.current_user.must_equal(user)
    end

    it "makes controller requests pass through" do
      login(user)
      call_action
    end

    it "allows post requests" do
      request['REQUEST_METHOD'] = 'POST'
      login(user)
      call_action
    end
  end

  describe "#disable_cache" do
    let(:dummy_cache) { Class.new(ActiveSupport::Cache::MemoryStore) }

    around do |test|
      begin
        old = Rails.cache
        Rails.cache = dummy_cache.new
        test.call
      ensure
        Rails.cache = old
      end
    end

    before { Rails.cache.write('x', 1) }

    it "caches when not called" do
      Rails.cache.read('x').must_equal 1
      Rails.cache.fetch('x') { 2 }.must_equal 1
    end

    it "does not cache when called" do
      disable_cache
      Rails.cache.read('x').must_equal nil
      Rails.cache.fetch('x') { 2 }.must_equal 2
    end
  end
end
