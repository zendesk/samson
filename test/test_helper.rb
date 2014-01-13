ENV["RAILS_ENV"] ||= "test"
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/rails'
require 'webmock/minitest'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

class ActiveSupport::TestCase
  include Warden::Test::Helpers

  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all
end

class ActionController::TestCase
  def self.it_is_unauthorized
    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end
  end

  setup do
    middleware = Rails.application.config.middleware.detect {|m| m.name == 'Warden::Manager'}
    manager = Warden::Manager.new(nil, &middleware.block)
    request.env['warden'] = Warden::Proxy.new(@request.env, manager)
  end

  teardown do
    Warden.test_reset!
  end

  def process_with_catch_warden(*args)
    catch(:warden) do
      process_without_catch_warden(*args)
    end
  end

  alias_method_chain :process, :catch_warden

  class << self
    %w{admin deployer viewer}.each do |user|
      define_method "as_a_#{user}" do |&block|
        describe "as a #{user}" do
          setup { request.env['warden'].set_user(users(user)) }
          instance_eval(&block)
        end
      end
    end
  end
end
