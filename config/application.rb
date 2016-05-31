require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(:preload)
Bundler.require(:assets) if Rails.env.development? || ENV["PRECOMPILE"]
if ['development', 'staging'].include?(Rails.env)
  require 'better_errors'
  require 'rack-mini-profiler'
end

Dotenv.load(Bundler.root.join(Rails.env.test? ? '.env.test' : '.env'))

module Samson
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    #

    config.autoload_paths += Dir["#{config.root}/lib/**/"]

    if Rails.env.test?
      config.cache_store = :memory_store
    else
      servers = []
      options = { value_max_bytes: 3000000, compress: true, expires_in: 1.day }

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

    # Raise exceptions
    config.active_record.raise_in_transactional_callbacks = true

    # Allow streaming
    config.preload_frameworks = true
    config.allow_concurrency = true

    # Used for all Samson specific configuration.
    config.samson = ActiveSupport::OrderedOptions.new

    # Email prefix e.g. [PREFIX] Someone deployed PROJECT to STAGE (REF)
    config.samson.email = ActiveSupport::OrderedOptions.new
    config.samson.email.prefix = ENV["EMAIL_PREFIX"].presence || "DEPLOY"
    config.samson.email.sender_domain = ENV["EMAIL_SENDER_DOMAIN"].presence || "samson-deployment.com"

    # Whether or not jobs are actually executed.
    config.samson.enable_job_execution = true

    # Tired of the i18n deprecation warning
    config.i18n.enforce_available_locales = true

    # The directory in which repositories should be cached.
    config.samson.cached_repos_dir = Rails.root.join("cached_repos")

    # The Github teams and organizations used for permissions
    config.samson.github = ActiveSupport::OrderedOptions.new
    config.samson.github.organization = ENV["GITHUB_ORGANIZATION"].presence
    config.samson.github.admin_team = ENV["GITHUB_ADMIN_TEAM"].presence
    config.samson.github.deploy_team = ENV["GITHUB_DEPLOY_TEAM"].presence
    config.samson.github.web_url = ENV["GITHUB_WEB_URL"].presence || 'github.com'
    config.samson.github.api_url = ENV["GITHUB_API_URL"].presence || 'api.github.com'
    config.samson.github.status_url = ENV["GITHUB_STATUS_URL"].presence || 'status.github.com'
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
    config.samson.gitlab.web_url = ENV["GITLAB_URL"].presence || 'gitlab.com'

    config.samson.auth = ActiveSupport::OrderedOptions.new
    config.samson.auth.github = ENV["AUTH_GITHUB"] == "1"
    config.samson.auth.google = ENV["AUTH_GOOGLE"] == "1"
    config.samson.auth.ldap = ENV["AUTH_LDAP"] == "1"
    config.samson.auth.gitlab = ENV["AUTH_GITLAB"] == "1"

    config.samson.docker = ActiveSupport::OrderedOptions.new
    config.samson.docker.registry = ENV['DOCKER_REGISTRY'].presence

    config.samson.uri = URI(ENV["DEFAULT_URL"] || 'http://localhost:3000')
    config.sse_rails_engine.access_control_allow_origin = config.samson.uri.to_s

    config.samson.stream_origin = ENV['STREAM_ORIGIN'].presence || config.samson.uri.to_s
    config.samson.deploy_origin = ENV['DEPLOY_ORIGIN'].presence || config.samson.uri.to_s

    self.default_url_options = {
      host: config.samson.uri.host,
      protocol: config.samson.uri.scheme
    }

    config.action_controller.action_on_unpermitted_parameters = :raise

    config.active_job.queue_adapter = :sucker_punch
    config.samson.export_job = ActiveSupport::OrderedOptions.new
    config.samson.export_job.downloaded_age = (ENV['EXPORT_JOB_DOWNLOADED_AGE'] || 12.hours).to_i
    config.samson.export_job.max_age = (ENV['EXPORT_JOB_MAX_AGE'] || 1.day).to_i

    if !Rails.env.test? && ENV['SERVER_MODE'] && !ENV['PRECOMPILE']
      # flowdock uses routes: run after the routes are loaded
      initializer :execute_job, after: :set_routes_reloader_hook do
        JobExecution.enabled = true

        Job.running.each(&:stop!)

        Job.non_deploy.pending.each do |job|
          JobExecution.start_job(JobExecution.new(job.commit, job))
        end

        Deploy.pending.each do |deploy|
          deploy.pending_start! unless deploy.waiting_for_buddy?
        end

        RestartSignalHandler.listen
        Samson::Tasks::LockCleaner.start
      end
    end

    unless ENV['PRECOMPILE']
      config.after_initialize do
        # Token used to request badges
        config.samson.badge_token = Digest::MD5.hexdigest('badge_token' << Samson::Application.config.secret_key_base)
      end
    end
  end
end

require 'samson/hooks'
