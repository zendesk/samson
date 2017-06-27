# frozen_string_literal: true
# Fill ENV from .env with Dotenv, to configure puma/RAILS_ENV/gems with .env
require 'dotenv'
Dotenv.load(Bundler.root.join('.env'))

# when we run rake we load the dev environment first and fork to load the test env
# so we need to overload what .env changed, load .env.test, and ignore system ENV
Dotenv.overload(Bundler.root.join('.env.test')) if ENV['RAILS_ENV'] == 'test'
