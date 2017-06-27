# frozen_string_literal: true
# Fill ENV from .env with Dotenv, to configure puma/RAILS_ENV/gems with .env
require 'dotenv'
ENV["SAMSON_ENV_KEYS_BEFORE_DOTENV"] ||= ENV.keys.join(",")

# when we run rake we load the dev environment first and fork to load the test env
# so we need to unset what .env changed and then load .env.test
if ENV['RAILS_ENV'] == 'test'
  (ENV.keys - ENV["SAMSON_ENV_KEYS_BEFORE_DOTENV"].split(",")).each { |k| ENV.delete(k) }
  Dotenv.load(Bundler.root.join('.env.test'))
else
  Dotenv.load(Bundler.root.join('.env'))
end
