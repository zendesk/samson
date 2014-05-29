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

    config.cache_store = :dalli_store, { value_max_bytes: 3000000, compress: true }

    # Allow streaming
    config.preload_frameworks = true
    config.allow_concurrency = true

    # Used for all Samson specific configuration.
    config.samson = ActiveSupport::OrderedOptions.new

    # Email prefix e.g. [PREFIX] Someone deployed PROJECT to STAGE (REF)
    config.samson.email_prefix = ENV["EMAIL_PREFIX"] || "DEPLOY"

    # Whether or not jobs are actually executed.
    config.samson.enable_job_execution = true

    # Tired of the i18n deprecation warning
    config.i18n.enforce_available_locales = true

    # The directory in which repositories should be cached.
    config.samson.cached_repos_dir = Rails.root.join("cached_repos")

    # The Github teams and organizations used for permissions
    config.samson.github = ActiveSupport::OrderedOptions.new
    config.samson.github.organization = ENV["GITHUB_ORGANIZATION"]
    config.samson.github.admin_team = ENV["GITHUB_ADMIN_TEAM"]
    config.samson.github.deploy_team = ENV["GITHUB_DEPLOY_TEAM"]
    config.samson.github.use_identicons = ENV["GITHUB_USE_IDENTICONS"].present?

    config.samson.uri = URI( ENV["DEFAULT_URL"] || 'http://localhost:9080' )
    self.default_url_options = {
      host: config.samson.uri.host,
      protocol: config.samson.uri.scheme
    }
  end
end
