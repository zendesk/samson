# frozen_string_literal: true
require 'bundler/setup'
require_relative 'dotenv'
require 'bootscale/setup' if ['development', 'test'].include?(ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development')
