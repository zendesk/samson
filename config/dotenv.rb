# frozen_string_literal: true
# Fill ENV from .env with Dotenv, to configure puma/RAILS_ENV/gems with .env
require 'dotenv'
before = ENV.keys
Dotenv.load('.env')

# when we run rake we load the dev environment first and then the test env
# so we need to reset what .env changed to be able to load .env.test without ignoring system ENV
if ENV['RAILS_ENV'] == 'test'
  (ENV.keys - before).each { |k| ENV.delete(k) }
  Dotenv.load('.env.test')
end
