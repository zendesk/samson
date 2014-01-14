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
  class << self
    def unauthorized(method, action, params = {})
      describe "a #{method} to #{action} with #{params}" do
        before { send(method, action, params) }

        it 'is unauthorized' do
          flash[:error].must_equal('You are not authorized to view this page.')
          assert_redirected_to root_url
        end
      end
    end

    %w{admin deployer viewer}.each do |user|
      define_method "as_a_#{user}" do |&block|
        describe "as a #{user}" do
          setup { request.env['warden'].set_user(users(user)) }
          instance_eval(&block)
        end
      end
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

  def warden
    request.env['warden']
  end

  def process_with_catch_warden(*args)
    catch(:warden) do
      process_without_catch_warden(*args)
    end
  end

  alias_method_chain :process, :catch_warden
end
