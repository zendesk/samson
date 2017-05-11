# frozen_string_literal: true
# Fill ENV from .env with Dotenv, to configure puma/RAILS_ENV/gems with .env

require 'dotenv'
before = ENV.keys
Dotenv.load(Bundler.root.join('.env'))

if ENV['RAILS_ENV'] == 'test'
  (ENV.keys - before).each { |k| ENV.delete(k) } # reset what .env changed
  Dotenv.load(Bundler.root.join('.env.test'))
end
