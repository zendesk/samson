# frozen_string_literal: true
Samson::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = !!ENV["PROFILE"]

  # Do not eager load code on boot.
  config.eager_load = !!ENV["PROFILE"]

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = !!ENV["PERFORM_CACHING"]

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false

  default_url_options[:port] = config.samson.uri.port

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = (ENV["PROFILE"] ? false : :page_load)

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = !ENV["PROFILE"]

  # Suppress logger output for asset requests.
  config.assets.quiet = !ENV["PROFILE"]

  # docker ships with precompiled assets, but we want dynamic assets in development
  config.assets.prefix = "/assets_dev"

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # logs are not free, so simulate production :info
  config.log_level = :info if ENV["PROFILE"]
end
