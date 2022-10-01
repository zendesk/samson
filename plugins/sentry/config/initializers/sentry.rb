# frozen_string_literal: true

if sentry_dsn = ENV['SENTRY_DSN']
  Sentry.init do |config|
    config.dsn = sentry_dsn
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.environment = Rails.env
    config.traces_sample_rate = 0
  end

  if sentry_project = ENV["SENTRY_PROJECT"].presence
    # setup 500 page links to errors see https://github.com/grosser/sentry-user_informer
    # to test enable sentry (see Readme.md) then visit /error page
    require 'samson/error_notifier'
    Sentry::UserInformer.template = Sentry::UserInformer.template.dup.sub!("/foo/", "/#{sentry_project}/") ||
      raise
    Sentry::UserInformer.placeholder = Samson::ErrorNotifier::USER_INFORMATION_PLACEHOLDER
  end
end
