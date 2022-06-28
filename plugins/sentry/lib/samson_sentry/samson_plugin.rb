# frozen_string_literal: true

require "sentry-ruby"
require "sentry-rails"

module SamsonSentry
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.callback :error do |exception, **options|
  sentry_options = options.slice(:contexts, :extra, :tags, :user, :level, :fingerprint)
  Sentry.capture_exception(exception, sentry_options)
end
