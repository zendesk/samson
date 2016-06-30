require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ConsoleExtensions do
  include Samson::ConsoleExtensions

  describe "#login" do
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

  describe "#logs" do
    around do |t|
      @old_logger = Rails.logger
      t.call
      Rails.logger = @old_logger
    end

    # make logs set our rigged stdout to the logger
    let(:stdout) { StringIO.new }
    before { Samson::ConsoleExtensions.const_set(:STDOUT, stdout) }
    after { Samson::ConsoleExtensions.send(:remove_const, :STDOUT) }

    it "makes logs show in stdout" do
      logs
      Rails.logger.warn 'test'
      stdout.string.must_include "WARN -- : test"
    end

    it "keeps logging to original logger" do
      logs
      @old_logger.expects(:add)
      Rails.logger.warn 'test'
    end

    it "restores old logger when called twice" do
      logs
      logs
      Rails.logger.must_equal @old_logger
    end
  end
end
