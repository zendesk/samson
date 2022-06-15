# frozen_string_literal: true

unless ENV['SENTRY_DSN'].nil?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.environment = Rails.env

    # We recommend adjusting this value in production:
    config.traces_sample_rate = 0
  end

  # make events clickable clickable
  Sentry::LoggingHelper.prepend(Module.new do
    def log_info(message)
      super(message.sub(
        /(\S+) to Sentry/,
        "https://sentry.io/organizations/#{project}/issues/?query=\\1 to Sentry"
      ))
    end
  end)
end
