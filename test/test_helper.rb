ENV["RAILS_ENV"] ||= "test"

require 'single_cov'
SingleCov::APP_FOLDERS << 'decorators'
SingleCov.setup :minitest

if ENV['CODECLIMATE_REPO_TOKEN']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.start
elsif ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

# rake adds these, but we don't need them / want to be in a consistent environment
$LOAD_PATH.delete 'lib'
$LOAD_PATH.delete 'test'

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

  after { fail_if_dangling_threads }

  def fail_if_dangling_threads
    max_threads = 1 # Timeout.timeout adds a thread
    raise "Test left dangling threads: #{extra_threads}" if extra_threads.count > max_threads
  ensure
    kill_extra_threads
  end

  def kill_extra_threads
    extra_threads.map(&:kill).map(&:join)
  end

  def extra_threads
    if @before_threads
      Thread.list - @before_threads
    else
      []
    end
  end

  def assert_valid(record)
    assert record.valid?, record.errors.full_messages
  end

  def refute_valid(record, error_keys = nil)
    refute record.valid?, "Expected record of type #{record.class.name} to be invalid"

    Array.wrap(error_keys).compact.each do |key|
      record.errors.keys.must_include key
    end
  end

  def ar_queries
    require 'query_diet'
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

  undef :assert_nothing_raised
  class << self
    undef :test
  end

  def create_secret(key)
    SecretStorage::DbBackend::Secret.create!(id: key, value: 'MY-SECRET', updater_id: users(:admin).id, creator_id: users(:admin).id)
  end

  def with_env(env)
    old = env.map do |k, v|
      k = k.to_s
      o = ENV[k]
      ENV[k] = v
      [k, o]
    end
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
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
        assert_unauthorized
      end
    end

    %w{super_admin admin deployer viewer project_admin project_deployer}.each do |user|
      define_method "as_a_#{user}" do |&block|
        describe "as a #{user}" do
          let(:user) { users(user) }
          before { request.env['warden'].set_user(self.user) }
          instance_eval(&block)
        end
      end
    end
  end

  before do
    middleware = Rails.application.config.middleware.detect {|m| m.name == 'Warden::Manager'}
    manager = Warden::Manager.new(nil, &middleware.block)
    request.env['warden'] = Warden::Proxy.new(request.env, manager)

    stub_request(:get, "https://#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
    create_default_stubs
  end

  after do
    Warden.test_reset!
  end

  def set_form_authenticity_token
    session[:_csrf_token] = SecureRandom.base64(32)
  end

  def warden
    request.env['warden']
  end

  def assert_unauthorized
    @unauthorized.must_equal true, "Request was not marked unauthorized"
  end

  def refute_unauthorized
    refute @unauthorized, "Request was marked unauthorized"
  end

  def process_with_catch_warden(*args)
    catch(:warden) do
      return process_without_catch_warden(*args)
    end

    @unauthorized = true
  end

  alias_method_chain :process, :catch_warden

  def self.use_test_routes
    before do
      Rails.application.routes.draw do
        match "/test/:test_route/:controller/:action", :via => [:get, :post, :put, :patch, :delete]
      end
    end

    after do
      Rails.application.reload_routes!
    end
  end
end

WebMock.disable_net_connect!(allow: 'codeclimate.com')

Dir["test/support/*"].each { |f| require File.expand_path(f) }
