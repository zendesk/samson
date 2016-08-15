# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ConsoleExtensions do
  describe "#login" do
    include Samson::ConsoleExtensions

    class ConsoleExtensionTestController < ApplicationController
      # turned off in test ... but we want to simulate it
      def allow_forgery_protection
        true
      end

      include CurrentUser
      before_filter :authorize_super_admin!

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
end
