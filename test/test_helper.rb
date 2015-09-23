ENV["RAILS_ENV"] ||= "test"

ENV['PROJECT_CREATED_NOTIFY_ADDRESS'] = 'blah@example.com'

if ENV['CODECLIMATE_REPO_TOKEN']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
elsif ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/rails'
require 'maxitest/autorun'
require 'webmock/minitest'
require 'mocha/setup'

# Use ActiveSupport::TestCase for everything that was not matched before
MiniTest::Spec::DSL::TYPES[-1] = [//, ActiveSupport::TestCase]

module StubGithubAPI
  def stub_github_api(url, response = {}, status = 200)
    url = 'https://api.github.com/' + url
    stub_request(:get, url).to_return(
      status: status,
      body: JSON.dump(response),
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end

module DefaultStubs
  def create_default_stubs
    SseRailsEngine.stubs(:send_event).returns(true)
    Project.any_instance.stubs(:clone_repository).returns(true)
    Project.any_instance.stubs(:clean_repository).returns(true)
  end

  def undo_default_stubs
    Project.any_instance.unstub(:clone_repository)
    Project.any_instance.unstub(:clean_repository)
    SseRailsEngine.unstub(:send_event)
  end
end

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  include StubGithubAPI
  include DefaultStubs

  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  Samson::Hooks.plugin_test_setup
  fixtures :all

  before do
    @before_threads = Thread.list
    Rails.cache.clear
    create_default_stubs
  end

  unless ENV['SKIP_TIMEOUT']
    after { fail_if_dangling_threads }
  end

  def fail_if_dangling_threads
    max_threads = ENV['CI'] ? 0 : 1
    raise "Test left dangling threads: #{extra_threads}" if extra_threads.count > max_threads
  ensure
    kill_extra_threads
  end

  def kill_extra_threads
    extra_threads.map(&:kill).map(&:join)
  end

  def extra_threads
    Thread.list - @before_threads
  end

  def assert_valid(record)
    assert record.valid?, record.errors.full_messages
  end

  def refute_valid(record)
    refute record.valid?
  end

  def ar_queries
    QueryDiet::Logger.queries.map(&:first) - ["select 1"]
  end

  def assert_sql_queries(count, &block)
    old = ar_queries
    yield
    new = ar_queries
    new_count = new.size - old.size
    message = new[old.size..-1].join("\n")
    if count.is_a?(Range)
      assert_includes count, new_count, message
    else
      assert_equal count, new_count, message
    end
  end

  # record hook and their arguments called during a given block
  def record_hooks(callback, &block)
    called = []
    Samson::Hooks.with_callback(callback, lambda{ |*args| called << args }, &block)
    called
  end

  def silence_stderr
    old, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old
  end
end

Mocha::Expectation.class_eval do
  def capture(into)
    with { |*args| into << args }
  end
end

class ActionController::TestCase
  include StubGithubAPI
  include DefaultStubs

  class << self
    def unauthorized(method, action, params = {})
      it "is unauthorized when doing a #{method} to #{action} with #{params}" do
        send(method, action, params)
        @unauthorized.must_equal true, "Request was not marked unauthorized"
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

    %w{deployer_project_admin}.each do |user|
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
    create_default_stubs
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

WebMock.disable_net_connect!(allow: 'codeclimate.com')

Dir["test/support/*"].each { |f| require File.expand_path(f) }
