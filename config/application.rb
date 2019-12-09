# frozen_string_literal: true
require_relative 'boot'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'action_cable/engine'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'

begin
  require 'pry-rails'
rescue LoadError # rubocop:disable Lint/HandleExceptions
  # ignore if pry-rails is not included in bundle
end

if (google_domain = ENV["GOOGLE_DOMAIN"]) && !ENV['EMAIL_DOMAIN']
  Rails.logger.warn "Stop using deprecated GOOGLE_DOMAIN"
  ENV["EMAIL_DOMAIN"] = google_domain.sub('@', '')
end

Bundler.require(:preload)
Bundler.require(:assets) if Rails.env.development? || ENV["PRECOMPILE"]

###
# Railties need to be loaded before the application is initialized
require 'omniauth'
require 'omniauth/rails_csrf_protection'

if ['development', 'staging'].include?(Rails.env) && ENV["SERVER_MODE"]
  require 'rack-mini-profiler' # side effect: removes expires headers
  Rack::MiniProfiler.config.authorization_mode = :allow_all
end
# END Railties
###

require_relative "../lib/samson/env_check"
# other requires should live at the bottom of the file

module Samson
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # TODO: use 6.0 ... check migration etc
    config.load_defaults 5.2

    # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
    config.force_ssl = (ENV["FORCE_SSL"] == "1")
    config.ssl_options = {redirect: {exclude: ->(request) { request.path.match?(/^\/ping(\/|$)/) }}}

    class ApplicationConfiguration
      def self.deprecated_url(var)
        url = ENV[var].presence
        return url if !url || url.start_with?('http')
        raise "Using deprecated url without protocol for #{var}"
      end
    end

    config.eager_load_paths << "#{config.root}/lib"

    case ENV["CACHE_STORE"]
    when "memory"
      config.cache_store = :memory_store # to debug cache keys, bundle open activesupport -> active_support/cache.rb#log
    when "memcached"
      options = {
        value_max_bytes: 3000000,
        compress: true,
        expires_in: 7.days,
        namespace: "samson-#{Rails.version}-#{RUBY_VERSION}",
        pool_size: [Integer(ENV.fetch('RAILS_MAX_THREADS', '250')) / 10, 2].max # 1/10 th of threads, see puma.rb
      }

      # support memcachier env used by heroku
      # https://devcenter.heroku.com/articles/memcachier#rails-3-and-4
      if ENV["MEMCACHIER_SERVERS"]
        servers = (ENV["MEMCACHIER_SERVERS"]).split(",")
        options.merge!(
          username: ENV["MEMCACHIER_USERNAME"],
          password: ENV["MEMCACHIER_PASSWORD"],
          failover: true,
          socket_timeout: 1.5,
          socket_failure_delay: 0.2
        )
      else
        servers = ["localhost:11211"]
      end
      config.cache_store = :mem_cache_store, servers, options
    else
      raise "Set CACHE_STORE environment variable to either memory or memcached"
    end

    # Allow streaming
    config.preload_frameworks = true
    config.allow_concurrency = true

    # TODO: allow ping-controller to not need ssl
    config.force_ssl = (ENV['FORCE_SSL'] == '1')

    # Used for all Samson specific configuration.
    config.samson = ActiveSupport::OrderedOptions.new

    # Email prefix e.g. [PREFIX] Someone deployed PROJECT to STAGE (REF)
    config.samson.email = ActiveSupport::OrderedOptions.new
    config.samson.email.prefix = ENV["EMAIL_PREFIX"].presence || "DEPLOY"
    config.samson.email.sender_domain = ENV["EMAIL_SENDER_DOMAIN"].presence || "samson-deployment.com"

    # Tired of the i18n deprecation warning
    config.i18n.enforce_available_locales = true

    # The directory in which repositories should be cached.
    config.samson.cached_repos_dir = Rails.root.join("cached_repos")

    # The Github teams and organizations used for permissions
    config.samson.github = ActiveSupport::OrderedOptions.new
    config.samson.github.organization = ENV["GITHUB_ORGANIZATION"].presence
    config.samson.github.admin_team = ENV["GITHUB_ADMIN_TEAM"].presence
    config.samson.github.deploy_team = ENV["GITHUB_DEPLOY_TEAM"].presence
    config.samson.github.web_url = ApplicationConfiguration.deprecated_url("GITHUB_WEB_URL") || 'https://github.com'
    config.samson.github.api_url = ApplicationConfiguration.deprecated_url("GITHUB_API_URL") || 'https://api.github.com'

    # Configuration for LDAP
    config.samson.ldap = ActiveSupport::OrderedOptions.new
    config.samson.ldap.title = ENV["LDAP_TITLE"].presence
    config.samson.ldap.host = ENV["LDAP_HOST"].presence
    config.samson.ldap.port = ENV["LDAP_PORT"].presence
    config.samson.ldap.base = ENV["LDAP_BASE"].presence
    config.samson.ldap.uid = ENV["LDAP_UID"].presence
    config.samson.ldap.bind_dn = ENV["LDAP_BINDDN"].presence
    config.samson.ldap.password = ENV["LDAP_PASSWORD"].presence

    config.samson.gitlab = ActiveSupport::OrderedOptions.new
    config.samson.gitlab.web_url = ApplicationConfiguration.deprecated_url("GITLAB_URL") || 'https://gitlab.com'

    config.samson.auth = ActiveSupport::OrderedOptions.new
    config.samson.auth.github = Samson::EnvCheck.set?("AUTH_GITHUB")
    config.samson.auth.google = Samson::EnvCheck.set?("AUTH_GOOGLE")
    config.samson.auth.ldap = Samson::EnvCheck.set?("AUTH_LDAP")
    config.samson.auth.gitlab = Samson::EnvCheck.set?("AUTH_GITLAB")
    config.samson.auth.bitbucket = Samson::EnvCheck.set?("AUTH_BITBUCKET")

    config.samson.uri = URI(
      ENV["DEFAULT_URL"] ||
      ((app = ENV["HEROKU_APP_NAME"]) && "https://#{app}.herokuapp.com") ||
      'http://localhost:3000'
    )

    raise if ENV['STREAM_ORIGIN'] || ENV['DEPLOY_ORIGIN'] # alert users with deprecated options, remove 2019-05-01

    config.samson.deploy_timeout = Integer(ENV["DEPLOY_TIMEOUT"] || 2.hours.to_i)

    self.default_url_options = {
      host: config.samson.uri.host,
      protocol: config.samson.uri.scheme
    }

    config.action_controller.action_on_unpermitted_parameters = :raise
    config.action_view.default_form_builder = 'Samson::FormBuilder' # string so we can auto-reload it

    config.samson.export_job = ActiveSupport::OrderedOptions.new
    config.samson.export_job.downloaded_age = Integer(ENV['EXPORT_JOB_DOWNLOADED_AGE'] || 12.hours)
    config.samson.export_job.max_age = Integer(ENV['EXPORT_JOB_MAX_AGE'] || 1.day)
    config.samson.start_time = Time.now

    # flowdock uses routes: run after the routes are loaded which happens after after_initialize
    # config.ru sets SERVER_MODE after application.rb is loaded when using `rails s`
    initializer :execute_job, after: :set_routes_reloader_hook do
      if !Rails.env.test? && ENV['SERVER_MODE'] && !ENV['PRECOMPILE']
        RestartSignalHandler.after_restart
        RestartSignalHandler.listen
      end
      Samson::BootCheck.check if Rails.env.development?
    end

    unless ENV['PRECOMPILE']
      config.after_initialize do
        require_relative "../lib/samson/mapped_database_exceptions"

        # Token used to request badges
        config.samson.badge_token = \
          Digest::MD5.hexdigest('badge_token' + (ENV['BADGE_TOKEN_BASE'] || Samson::Application.config.secret_key_base))
      end
    end

    config.active_support.deprecation = :raise

    # avoid permission errors in production and cleanliness test failures in test
    config.active_record.dump_schema_after_migration = Rails.env.development? && ENV["RAILS_DUMP_SCHEMA"] != "false"
  end

  RELEASE_NUMBER = '\d+(:?\.\d+)*'
end

# Configure sensitive parameters which will be filtered from the log files + errors
# Must be here instead of in an initializer because plugin initializers run before app initializers
# Used in plugins/airbrake + rollbar which do not support the 'foo.bar' syntax as rails does
# https://github.com/airbrake/airbrake-ruby/issues/137
Samson::Application.config.session_key = :"_samson_session_#{Rails.env}"
Rails.application.config.filter_parameters.concat [
  :password, :value, :value_hashed, :token, :access_token, Samson::Application.config.session_key, 'HTTP_AUTHORIZATION'
]

# Avoid starting up another background thread if we don't need it, see lib/samson/boot_check.rb
if ["test", "development"].include?(Rails.env)
  ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper.define_method(:run) {}
end

require 'samson/hooks'

require_relative "../lib/samson/syslog_formatters"
require_relative "../lib/samson/logging"
require_relative "../lib/samson/initializer_logging"
require_relative "../app/models/job_queue" # need to load early or dev reload will lose the .enabled

# prevents `Unknown validator: 'Doorkeeper::RedirectUriValidator'`
# https://github.com/doorkeeper-gem/doorkeeper/pull/1331
require 'doorkeeper/orm/active_record/redirect_uri_validator'
