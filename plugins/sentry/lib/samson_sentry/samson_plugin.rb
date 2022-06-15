# frozen_string_literal: true

require "sentry-ruby"
require "sentry-rails"

module SamsonSentry
  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.callback :error do |exception, **options|
  Sentry.capture_exception(exception, options)
end
