# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 2

describe Samson::ConsoleExtensions do
  include Samson::ConsoleExtensions

  with_forgery_protection

  describe "#login" do
    class ConsoleExtensionTestController < ApplicationController # rubocop:disable Lint/ConstantDefinitionInBlock
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

  describe "#use_clean_cache" do
    around do |test|
      begin
        old = Rails.cache
        test.call
      ensure
        Rails.cache = old
      end
    end

    before { Rails.cache.write('x', 1) }

    it "replaces cache" do
      use_clean_cache
      Rails.cache.read('x').must_equal nil
    end

    it "can still cache" do
      use_clean_cache
      Rails.cache.write('x', 2)
      Rails.cache.read('x').must_equal 2
    end
  end

  describe "#flamegraph" do
    it "can graph" do
      capture_stdout do
        flamegraph(name: "foo") { 15.times { sleep 0.1 } }
      end
      assert File.exist?("foo.js")
    ensure
      FileUtils.rm_f("foo.js")
    end
  end
end
