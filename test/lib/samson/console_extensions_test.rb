require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ConsoleExtensions do
  describe "#login" do
    include Samson::ConsoleExtensions

    class ConsoleExtensionTestController < ApplicationController
      include CurrentUser
      before_filter :authorize_super_admin!

      def secret
        render plain: 'OK'
      end

      private

      def verified_request?
        true
      end
    end

    let(:request) { {'rack.input' => StringIO.new, 'REQUEST_METHOD' => 'GET'} }
    let(:user) { users(:super_admin) }

    # modify our fake class and not the original to not break all other tests
    before { Samson::ConsoleExtensions.const_set(:CurrentUser, ConsoleExtensionTestController) }
    after { Samson::ConsoleExtensions.send(:remove_const, :CurrentUser) }

    it "sets user to given user" do
      login(user)
      ConsoleExtensionTestController.new.current_user.must_equal(user)
    end

    it "makes controller requests pass through" do
      login(user)
      status, _headers, body = ConsoleExtensionTestController.action(:secret).call(request)
      status.must_equal 200
      body.body.to_s.must_equal 'OK'
    end
  end
end
