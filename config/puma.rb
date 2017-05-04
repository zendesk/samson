# frozen_string_literal: true
require_relative "boot"

threads ENV.fetch('RAILS_MIN_THREADS', 8), ENV.fetch('RAILS_MAX_THREADS', 250)
preload_app!

port = 9080

# make dev puma boot on port 3000
# remove once https://github.com/puma/puma/pull/1277 is released
port = 3000 if (ENV["RAILS_ENV"] || "development") == "development"

bind "tcp://0.0.0.0:#{port}"
