# frozen_string_literal: true
require_relative "boot"

threads ENV.fetch('RAILS_MIN_THREADS', 8), ENV.fetch('RAILS_MAX_THREADS', 250)
preload_app!

bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 9080)}"
