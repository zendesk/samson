# frozen_string_literal: true
# This file is used by Rack-based servers to start the application.
ENV['SERVER_MODE'] = '1'
require_relative 'config/environment'
run Rails.application
