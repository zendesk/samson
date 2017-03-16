# frozen_string_literal: true
ENV["RAILS_ENV"] = "test"

require 'bundler/setup'

# anything loaded before coverage will be uncovered
require 'single_cov'
SingleCov::APP_FOLDERS << 'decorators' << 'presenters'
SingleCov.setup :minitest unless defined?(Spring)

# rake adds these, but we don't need them / want to be consistent with using `ruby x_test.rb`
$LOAD_PATH.delete 'lib'
$LOAD_PATH.delete 'test'

require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/rails'
require 'rails-controller-testing'
require 'maxitest/autorun'
require 'maxitest/timeout'
require 'webmock/minitest'
require 'mocha/setup'

require 'sucker_punch/testing/inline'

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

  Samson::Hooks.symlink_plugin_fixtures
  fixtures :all

  before do
    Rails.cache.clear
    create_default_stubs
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

  def freeze_time
    Time.stubs(:now).returns(Time.new(2001, 2, 3, 4, 5, 6))
  end

  def ar_queries
    require 'query_diet'
    QueryDiet::Logger.queries.map(&:first) - ["select 1"]
  end

  def assert_sql_queries(count)
    old = ar_queries
    yield
    new = ar_queries
    extra = new[old.size..-1].reject { |q| q =~ /information_schema|sqlite_temp_master|pg_constraint|pg_attribute/ }
    message = extra.join("\n")
    if count.is_a?(Range)
      assert_includes count, extra.count, message
    else
      assert_equal count, extra.count, message
    end
  end

  # record hook and their arguments called during a given block
  def record_hooks(callback, &block)
    called = []
    Samson::Hooks.with_callback(callback, lambda { |*args| called << args }, &block)
    called
  end

  def silence_stderr
    old = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = old
  end

  undef :assert_nothing_raised
  class << self
    undef :test
  end

  def create_secret(key)
    SecretStorage::DbBackend::Secret.create!(
      id: key,
      value: 'MY-SECRET',
      visible: false,
      comment: 'this is secret',
      updater_id: users(:admin).id,
      creator_id: users(:admin).id
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
    old.each { |k, v| ENV[k] = v } if old
  end

  def self.with_env(env)
    around { |test| with_env(env, &test) }
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
    around do |test|
      begin
        old = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        test.call
      ensure
        ActionController::Base.allow_forgery_protection = old
      end
    end
  end

  def self.with_paper_trail
    around { |t| PaperTrail.with_logging(&t) }
  end

  def self.with_registries(registries)
    around do |test|
      begin
        old = ENV['DOCKER_REGISTRIES']
        ENV['DOCKER_REGISTRIES'] = registries.join(',').presence
        DockerRegistry.instance_variable_set :@all, nil
        test.call
      ensure
        DockerRegistry.instance_variable_set :@all, nil
        ENV['DOCKER_REGISTRIES'] = old
      end
    end
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
        public_send method, action, params: params, format: (@request_format || :html)
        assert_response :unauthorized
      end
    end

    %w[super_admin admin deployer viewer project_admin project_deployer].each do |user|
      define_method "as_a_#{user}" do |&block|
        describe "as a #{user}" do
          let(:user) { users(user) }

          def self.let(*args)
            raise "Cannot override :user in as_a_*" if args.first.to_sym == :user
            super
          end

          before { login_as(self.user) } # rubocop:disable Style/RedundantSelf
          instance_eval(&block)
        end
      end
    end
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

  before do
    middleware = Rails.application.config.middleware.detect { |m| m.name == 'Warden::Manager' }
    manager = Warden::Manager.new(nil, &middleware.block)
    request.env['warden'] = Warden::Proxy.new(request.env, manager)
    stub_request(:get, "#{Rails.application.config.samson.github.status_url}/api/status.json").to_timeout
    create_default_stubs
  end

  after do
    Warden.test_reset!
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

  def self.oauth_setup!
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

  def self.use_test_routes(controller)
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

# https://github.com/blowmage/minitest-rails/issues/195
class ActionController::TestCase
  # Use AD::IntegrationTest for the base class when describing a controller
  register_spec_type(self) do |desc|
    desc.is_a?(Class) && desc < ActionController::Metal
  end
end

ActiveRecord::Base.logger.level = 1
WebMock.disable_net_connect!(allow: 'codeclimate.com')

Dir["test/support/*"].each { |f| require File.expand_path(f) }
