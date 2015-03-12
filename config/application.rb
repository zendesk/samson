require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, :assets, Rails.env)

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

    config.cache_store = :dalli_store, { value_max_bytes: 3000000, compress: true, expires_in: 1.day }

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

    config.samson.auth = ActiveSupport::OrderedOptions.new
    config.samson.auth.github = ENV["AUTH_GITHUB"] == "0" ? false : true
    config.samson.auth.google = ENV["AUTH_GOOGLE"] == "0" ? false : true

    config.samson.uri = URI( ENV["DEFAULT_URL"] || 'http://localhost:3000' )
    self.default_url_options = {
      host: config.samson.uri.host,
      protocol: config.samson.uri.scheme
    }

    config.action_controller.action_on_unpermitted_parameters = :raise

    config.after_initialize do
      # Token used to request badges
      unless ENV['PRECOMPILE']
        config.samson.badge_token = Digest::MD5.hexdigest('badge_token' << Samson::Application.config.secret_key_base)
      end
    end
  end
end

require "samson/hooks"
