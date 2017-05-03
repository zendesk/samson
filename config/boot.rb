# frozen_string_literal: true
require 'bundler/setup'
raise "ENV clearing failed" if File.expand_path(ENV.fetch("BUNDLE_GEMFILE")) != File.expand_path("Gemfile")
require_relative 'dotenv'
require 'bootscale/setup' if ['development', 'test'].include?(ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development')
