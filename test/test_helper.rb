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

class ActiveSupport::TestCase
  include Warden::Test::Helpers
  include StubGithubAPI

  ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  before do
    Rails.cache.clear
    stubs_project_callbacks
  end

  after { sleep 0.1 while extra_threads.present? }

  def extra_threads
    normal = ENV['CI'] ? 2 : 3 # there are always 3 threads hanging around, 2 unknown and 1 from the test timeout helper code
    threads = (Thread.list - [Thread.current])
    raise "too low threads, adjust minimum" if threads.size < normal
    threads.sort_by(&:object_id)[normal..-1] # always kill the newest threads (run event_streamer_test.rb + stage_test.rb to make it blow up)
  end

  def assert_valid(record)
    assert record.valid?, record.errors.full_messages
  end

  def refute_valid(record)
    refute record.valid?
  end

  def stubs_project_callbacks
    Project.any_instance.stubs(:clone_repository).returns(true)
    Project.any_instance.stubs(:clean_repository).returns(true)
  end

  def unstub_project_callbacks
    Project.any_instance.unstub(:clone_repository)
    Project.any_instance.unstub(:clean_repository)
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
  end

  def unauthorized(*args)
    self.class.unauthorized(*args)
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

WebMock.disable_net_connect!(allow: 'codeclimate.com')

Dir["test/support/*"].each { |f| require File.expand_path(f) }
