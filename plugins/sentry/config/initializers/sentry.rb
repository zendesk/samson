# frozen_string_literal: true

if sentry_dsn = ENV['SENTRY_DSN']
  Sentry.init do |config|
    config.dsn = sentry_dsn
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.environment = Rails.env

    # We recommend adjusting this value in production:
    config.traces_sample_rate = 1
  end

  Sentry.capture_message("test")

  # make events clickable see https://github.com/getsentry/sentry-ruby/issues/1786
  unless ENV["SENTRY_PROJECT"].nil?
    Sentry::LoggingHelper.prepend(Module.new do
      def log_info(message)
        super(message.sub(
          /(\S+) to Sentry/, "https://sentry.io/organizations/#{ENV["SENTRY_PROJECT"]}/issues/?query=\\1 to Sentry"
        ))
      end
    end)
  end
end
