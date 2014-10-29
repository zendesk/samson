ENV["RAILS_ENV"] ||= "test"

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/rails'
require 'maxitest/autorun'
require 'webmock/minitest'

class ActiveSupport::TestCase
  include Warden::Test::Helpers

  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  before do
    Rails.cache.clear
  end
end

module StubGithubAPI
  def stub_github_api(url, response = {}, status = 200)
    url = 'https://api.github.com/' + url
    stub_request(:get, url).with(
      'Authorization' => 'token 123'
    ).to_return(
      status: status,
      body: JSON.dump(response),
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end

class MiniTest::Spec
  include StubGithubAPI
end

Mocha::Expectation.class_eval do
  def capture(into)
    with { |*args| into << args }
  end
end

class ActionController::TestCase
  include StubGithubAPI

  class << self
    def unauthorized(method, action, params = {})
      describe "a #{method} to #{action} with #{params}" do
        before { send(method, action, params) }

        it 'is unauthorized' do
          assert_equal true, @unauthorized
        end
      end
    end

    %w{super_admin admin deployer viewer}.each do |user|
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
    request.env['warden'] = Warden::Proxy.new(request.env, manager)

    stub_request(:get, "https://#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
  end

  teardown do
    Warden.test_reset!
  end

  def warden
    request.env['warden']
  end

  def process_with_catch_warden(*args)
    catch(:warden) do
      return process_without_catch_warden(*args)
    end

    @unauthorized = true
  end

  alias_method_chain :process, :catch_warden
end

Dir["test/support/*"].each { |f| require File.expand_path(f) }
