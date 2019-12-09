# frozen_string_literal: true
ENV["RAILS_ENV"] = "test"

require 'bundler/setup'

# anything loaded before coverage will be uncovered
require 'single_cov'
SingleCov::APP_FOLDERS << 'decorators' << 'presenters'
SingleCov.setup :minitest, branches: true unless defined?(Spring)

# rake adds these, but we don't need them / want to be consistent with using `ruby x_test.rb`
$LOAD_PATH.delete 'lib'
$LOAD_PATH.delete 'test'

require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/rails'
require 'rails-controller-testing'
Rails::Controller::Testing.install
require 'maxitest/autorun'
require 'maxitest/timeout'
require 'maxitest/threads'
require 'webmock/minitest'
require 'mocha/setup'

# Use ActiveSupport::TestCase for everything that was not matched before
MiniTest::Spec::DSL::TYPES[-1] = [//, ActiveSupport::TestCase]

# Use ActionController::TestCase for Controllers
MiniTest::Spec::DSL::TYPES.unshift [/Controller$/, ActionController::TestCase]

# Use ActionDispatch::IntegrationTest for everything that is marked Integration
MiniTest::Spec::DSL::TYPES.unshift [/Integration$/, ActionDispatch::IntegrationTest]

# Use ActionView::TestCase for Helpers
MiniTest::Spec::DSL::TYPES.unshift [/Helper$/, ActionView::TestCase]

Mocha::Expectation.class_eval do
  def capture(into)
    with { |*args| into << args }
  end
end

ActiveRecord::Migration.check_pending!

Samson::Hooks.symlink_plugin_fixtures

ActiveRecord::Base.logger.level = 1
WebMock.disable_net_connect!(allow: 'codeclimate.com')

Dir["test/support/*"].each { |f| require File.expand_path(f) }

# global view-context so templates are cached, to prevent undefined method errors
# TODO: find a better workaround so plugins/env/test/samson_env/samson_plugin_test.rb passes but without global variable
TEST_VIEW_CONTEXT ||= begin
  lookup_context = ActionView::Base.build_lookup_context(ActionController::Base.view_paths)
  view_context = ActionView::Base.with_empty_template_cache.new(lookup_context)
  class << view_context
    include Rails.application.routes.url_helpers
    include ApplicationHelper
  end
  view_context.instance_eval do
    # stub for testing render
    def protect_against_forgery?
    end
  end
  view_context
end

# Helpers for all tests
ActiveSupport::TestCase.class_eval do
  include ApplicationHelper
  include Warden::Test::Helpers

  fixtures :all

  before { Rails.cache.clear }

  def assert_valid(record)
    assert record.valid?, record.errors.full_messages
  end

  def refute_valid(record, error_keys = nil)
    refute record.valid?, "Expected record of type #{record.class.name} to be invalid"

    Array.wrap(error_keys).compact.each do |key|
      record.errors.keys.must_include key
    end
  end

  def refute_valid_on(model, attribute, message)
    assert_predicate model, :invalid?
    assert_includes model.errors.full_messages_for(attribute), message
  end

  def freeze_time
    Time.stubs(:now).returns(Time.new(2001, 2, 3, 4, 5, 6))
  end

  # record hook and their arguments called during a given block
  def record_hooks(callback, &block)
    called = []
    Samson::Hooks.with_callback(callback, ->(*args) { called << args }, &block)
    called
  end

  def silence_stderr
    old = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = old
  end

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

  undef :assert_nothing_raised
  class << self
    undef :test
  end

  def create_secret(id, extra = {})
    Samson::Secrets::Manager.write(
      id,
      {
        value: 'MY-SECRET',
        visible: false,
        comment: 'this is secret',
        user_id: users(:admin).id,
        deprecated_at: nil
      }.merge(extra)
    )
    Samson::Secrets::DbBackend::Secret.find(id) # TODO: just return id
  end

  def create_vault_server(overrides = {})
    Samson::Secrets::VaultServer.any_instance.stubs(:validate_connection)
    Samson::Secrets::VaultServer.create!(
      {name: "pod1", address: 'http://vault-land.com', token: 'TOKEN'}.merge(overrides)
    )
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
    # the `if old` is here to not blow up with nil.each when setting the env failed
    old&.each { |k, v| ENV[k] = v }
  end

  def self.with_env(env)
    around { |test| with_env(env, &test) }
  end

  def with_config(key, value)
    config = Rails.application.config.samson
    old = config.send(key)

    config.send("#{key}=", value)
    yield
  ensure
    config.send("#{key}=", old)
  end

  def self.with_config(*args)
    around { |test| with_config(*args, &test) }
  end

  def self.run_inside_of_temp_directory
    around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }
  end

  def self.assert_route(verb, path, to:, params: {})
    controller, action = to.split("#", 2)
    it_name = "routes to #{controller} #{action}"
    it_name += params.keys.empty? ? " with no parameters" : " with parameters #{params}"

    describe "a #{verb} to #{path}" do
      it it_name do
        verb = verb.to_s.upcase
        assert_routing({method: verb, path: path}, {controller: controller, action: action}.merge(params))
      end
    end
  end

  def stub_session_auth
    Warden::SessionSerializer.any_instance.stubs(:session).returns("warden.user.default.key" => user.id)
  end

  def self.with_forgery_protection
    around { |test| with_forgery_protection(&test) }
  end

  def with_forgery_protection
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = old
  end

  def self.with_registries(registries)
    around { |test| with_registries(registries, &test) }
  end

  def with_registries(registries)
    old = ENV['DOCKER_REGISTRIES']
    ENV['DOCKER_REGISTRIES'] = registries.join(',').presence
    DockerRegistry.instance_variable_set :@all, nil
    yield
  ensure
    DockerRegistry.instance_variable_set :@all, nil
    ENV['DOCKER_REGISTRIES'] = old
  end

  def silence_thread_exceptions
    old = Thread.report_on_exception
    Thread.report_on_exception = false
    yield
  ensure
    Thread.report_on_exception = old
  end

  def stub_const(base, name, value)
    old = base.const_get(name)
    silence_warnings { base.const_set(name, value) }
    yield
  ensure
    silence_warnings { base.const_set(name, old) }
  end

  def self.only_callbacks_for_plugin(callback)
    line = caller(1..1).first
    plugin_name = line[/\/plugins\/([^\/]+)/, 1] || raise("not called from a plugin not #{line}")
    around { |t| Samson::Hooks.only_callbacks_for_plugin(plugin_name, callback, &t) }
  end

  def self.before_and_after(&block)
    before(&block)
    after(&block)
  end

  def view_context
    TEST_VIEW_CONTEXT
  end
end

# Helpers for controller tests
ActionController::TestCase.class_eval do
  class << self
    def unauthorized(method, action, params = {})
      it "is unauthorized when doing a #{method} to #{action} with #{params}" do
        public_send method, action, params: params, format: (@request_format || :html)
        assert_response :unauthorized
      end
    end

    def as_a(type, &block)
      describe "as a #{type}" do
        let(:user) { users(type) }
        before { login_as(user) }
        instance_exec(&block)
      end
    end

    def oauth_setup!
      let(:redirect_uri) { 'urn:ietf:wg:oauth:2.0:oob' }
      let(:oauth_app) do
        Doorkeeper::Application.new do |app|
          app.name = "Test App"
          app.redirect_uri = redirect_uri
          app.scopes = :default
        end
      end
      let(:user) { users(:admin) }
      let(:token) do
        oauth_app.access_tokens.new do |token|
          token.resource_owner_id = user.id
          token.application_id = oauth_app.id
          token.expires_in = 1000
          token.scopes = :default
        end
      end

      before do
        token.save!
        json!
        auth!("Bearer #{token.token}")
      end
    end

    def use_test_routes(controller)
      controller_name = controller.name.underscore.sub('_controller', '')
      before do
        Rails.application.routes.draw do
          controller.action_methods.each do |action|
            match(
              "/test/:test_route/#{action}",
              via: [:get, :post, :put, :patch, :delete],
              controller: controller_name,
              action: action
            )
          end
        end
      end

      after do
        Rails.application.reload_routes!
      end
    end
  end

  before do
    middleware = Rails.application.config.middleware.detect { |m| m.name == 'Warden::Manager' }
    manager = Warden::Manager.new(nil, &middleware.block)
    request.env['warden'] = Warden::Proxy.new(request.env, manager)
  end

  after do
    Warden.test_reset!
    ActionMailer::Base.deliveries.clear
  end

  # overrides warden/test/helpers.rb which does not work in controller tests
  # TODO: file a warden bug or figure out what we are doing wrong
  def login_as(user)
    user = users(user) if user.is_a?(Symbol)
    request.env['warden'].set_user(user)
  end

  def json!
    request.env['CONTENT_TYPE'] = 'application/json'
  end

  def auth!(header)
    request.env['HTTP_AUTHORIZATION'] = header
  end

  def warden
    request.env['warden']
  end

  # catch warden throw ... which would normally go into warden middleware and then be an unauthorized response
  prepend(Module.new do
    def process(*args)
      catch(:warden) { return super }
      response.status = :unauthorized
      response.body = ":warden caught in test_helper.rb"
      response
    end
  end)
end

ActionDispatch::IntegrationTest.class_eval do
  def self.as_a(type, &block)
    describe "as a #{type}" do
      before { ApplicationController.any_instance.stubs(current_user: users(type), login_user: true) }
      instance_exec(&block)
    end
  end

  # bring back helper that was removed in rails 5
  def assigns(name)
    @controller.instance_variable_get(:"@#{name}")
  end
end
