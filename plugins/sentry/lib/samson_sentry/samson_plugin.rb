# frozen_string_literal: true

# make events clickable see https://github.com/getsentry/sentry-ruby/issues/1786
# this needs to happen early so nothing includes the Sentry::LoggingHelper yet
# test: enable sentry (see Readme.md) + `rails c` + `Sentry.capture_message 'foo'` while sentry is enabled
if ENV["SENTRY_PROJECT"].present?
  require "sentry/utils/logging_helper"
  Sentry::LoggingHelper.prepend(Module.new do
    def log_info(message)
      super(message.sub(
        /(\S+) to Sentry/, "https://sentry.io/organizations/#{ENV["SENTRY_PROJECT"]}/issues/?query=\\1 to Sentry"
      ))
    end
  end)
end

require "sentry-rails"
require "sentry/user_informer"

module SamsonSentry
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.callback :error do |exception, **options|
  sentry_options = options.slice(:contexts, :extra, :tags, :user, :level, :fingerprint)
  Sentry.capture_exception(exception, sentry_options)
end
