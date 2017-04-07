# frozen_string_literal: true
require_relative 'boot'
require 'rails/all'

if (google_domain = ENV["GOOGLE_DOMAIN"]) && !ENV['EMAIL_DOMAIN']
  warn "Stop using deprecated GOOGLE_DOMAIN"
  ENV["EMAIL_DOMAIN"] = google_domain.sub('@', '')
end

Bundler.require(:preload)
Bundler.require(:assets) if Rails.env.development? || ENV["PRECOMPILE"]

###
# Railties need to be loaded before the application is defined
if ['development', 'staging'].include?(Rails.env)
  require 'better_errors'
  require 'rack-mini-profiler' # side effect: removes expires headers
end

if ['staging', 'production'].include?(Rails.env)
  require 'airbrake'
  require 'airbrake/user_informer'
  require 'newrelic_rpm'
else
  # avoids circular dependencies warning
  # https://discuss.newrelic.com/t/circular-require-in-ruby-agent-lib-new-relic-agent-method-tracer-rb/42737
  require 'new_relic/control'

  # needed even in dev/test mode
  require 'new_relic/agent/method_tracer'
end
# END Railties
###

require_relative "../lib/samson/env_check"

module Samson
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    deprecated_url = ->(var) do
      url = ENV[var].presence
      return url if !url || url.start_with?('http')
      warn "Using deprecated url without protocol for #{var}"
      "https://#{url}"
    end

    config.eager_load_paths << "#{config.root}/lib"

    if Rails.env.test?
      config.cache_store = :memory_store
    else
      servers = []
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
      end
      config.cache_store = :dalli_store, servers, options
    end

    # Allow streaming
    config.preload_frameworks = true
    config.allow_concurrency = true

    # Used for all Samson specific configuration.
    config.samson = ActiveSupport::OrderedOptions.new

    # Email prefix e.g. [PREFIX] Someone deployed PROJECT to STAGE (REF)
    config.samson.email = ActiveSupport::OrderedOptions.new
    config.samson.email.prefix = ENV["EMAIL_PREFIX"].presence || "DEPLOY"
    config.samson.email.sender_domain = ENV["EMAIL_SENDER_DOMAIN"].presence || "samson-deployment.com"

    # Email notifications
    config.samson.project_created_email = ENV["PROJECT_CREATED_NOTIFY_ADDRESS"]
    config.samson.project_deleted_email = ENV["PROJECT_DELETED_NOTIFY_ADDRESS"].presence ||
      ENV["PROJECT_CREATED_NOTIFY_ADDRESS"]

    # Tired of the i18n deprecation warning
    config.i18n.enforce_available_locales = true

    # The directory in which repositories should be cached.
    config.samson.cached_repos_dir = Rails.root.join("cached_repos")

    # The Github teams and organizations used for permissions
    config.samson.github = ActiveSupport::OrderedOptions.new
    config.samson.github.organization = ENV["GITHUB_ORGANIZATION"].presence
    config.samson.github.admin_team = ENV["GITHUB_ADMIN_TEAM"].presence
    config.samson.github.deploy_team = ENV["GITHUB_DEPLOY_TEAM"].presence
    config.samson.github.web_url = deprecated_url.call("GITHUB_WEB_URL") || 'https://github.com'
    config.samson.github.api_url = deprecated_url.call("GITHUB_API_URL") || 'https://api.github.com'
    config.samson.github.status_url = deprecated_url.call("GITHUB_STATUS_URL") || 'https://status.github.com'
    config.samson.references_cache_ttl = ENV['REFERENCES_CACHE_TTL'].presence || 10.minutes

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
    config.samson.gitlab.web_url = deprecated_url.call("GITLAB_URL") || 'https://gitlab.com'

    config.samson.auth = ActiveSupport::OrderedOptions.new
    config.samson.auth.github = Samson::EnvCheck.set?("AUTH_GITHUB")
    config.samson.auth.google = Samson::EnvCheck.set?("AUTH_GOOGLE")
    config.samson.auth.ldap = Samson::EnvCheck.set?("AUTH_LDAP")
    config.samson.auth.gitlab = Samson::EnvCheck.set?("AUTH_GITLAB")

    config.samson.uri = URI(ENV["DEFAULT_URL"] || 'http://localhost:3000')
    config.sse_rails_engine.access_control_allow_origin = config.samson.uri.to_s

    config.samson.stream_origin = ENV['STREAM_ORIGIN'].presence || config.samson.uri.to_s
    config.samson.deploy_origin = ENV['DEPLOY_ORIGIN'].presence || config.samson.uri.to_s

    self.default_url_options = {
      host: config.samson.uri.host,
      protocol: config.samson.uri.scheme
    }

    config.action_controller.action_on_unpermitted_parameters = :raise
    config.action_view.default_form_builder = 'Samson::FormBuilder' # string so we can auto-reload it

    config.active_job.queue_adapter = :sucker_punch
    config.samson.export_job = ActiveSupport::OrderedOptions.new
    config.samson.export_job.downloaded_age = Integer(ENV['EXPORT_JOB_DOWNLOADED_AGE'] || 12.hours)
    config.samson.export_job.max_age = Integer(ENV['EXPORT_JOB_MAX_AGE'] || 1.day)

    # flowdock uses routes: run after the routes are loaded
    # config.ru sets SERVER_MODE after application.rb is loaded when using `rails s`
    initializer :execute_job, after: :set_routes_reloader_hook do
      if !Rails.env.test? && ENV['SERVER_MODE'] && !ENV['PRECOMPILE']
        JobExecution.enabled = true

        Job.running.each { |j| j.stop!(nil) }

        Job.non_deploy.pending.each do |job|
          JobExecution.start_job(JobExecution.new(job.commit, job))
        end

        Deploy.start_deploys_waiting_for_restart!

        RestartSignalHandler.listen
      end
    end

    unless ENV['PRECOMPILE']
      config.after_initialize do
        # Token used to request badges
        config.samson.badge_token = \
          Digest::MD5.hexdigest('badge_token'.dup + Samson::Application.config.secret_key_base)
      end
    end

    # we want 'project' as root for project collections in controller responses
    ActiveModelSerializers.config.adapter = :json
  end
end

require 'samson/hooks'
require "#{Rails.root}/lib/samson/logging"
