Samson::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  self.default_url_options.merge!( port: config.samson.uri.port )

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false

  # Lograge
  # For testing purposes, you need to have something like this in your asl.conf (Mac OS X):
  # ? [= Sender samson] file /Users/myuser/Code/samson/log/samson.log mode=0644
  # require 'syslog/logger'
  # config.logger = Syslog::Logger.new('samson')
  if ENV['DOCKER'] == 'true'
    config.logger = Logger.new(STDOUT)
  end

  # config.lograge.enabled = true
  # config.lograge.formatter = Lograge::Formatters::Logstash.new

  BetterErrors::Middleware.allow_ip! ENV['TRUSTED_IP'] if ENV['TRUSTED_IP']
end
