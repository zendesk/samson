require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, :assets, Rails.env)

module ZendeskPusher
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

    config.cache_store = :dalli_store

    # Allow streaming
    config.preload_frameworks = true
    config.allow_concurrency = true

    # Used for all Pusher specific configuration.
    config.pusher = ActiveSupport::OrderedOptions.new

    # Whether or not jobs are actually executed.
    config.pusher.enable_job_execution = true

    # Tired of the i18n deprecation warning
    config.i18n.enforce_available_locales = true

    # The directory in which repositories should be cached.
    config.pusher.cached_repos_dir = Rails.root.join("cached_repos")

    # The Github teams and organizations used for permissions
    config.pusher.github = ActiveSupport::OrderedOptions.new
    config.pusher.github.organization = 'zendesk'
    config.pusher.github.admin_team = 'owners'
    config.pusher.github.deploy_team = 'engineering'
  end
end
