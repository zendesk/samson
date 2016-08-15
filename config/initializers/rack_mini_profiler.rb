# frozen_string_literal: true
Rack::MiniProfiler.config.authorization_mode = :allow_all if Rails.env.staging?
