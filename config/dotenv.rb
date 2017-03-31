# frozen_string_literal: true
# Fill ENV from .env with Dotenv, to configure puma/RAILS_ENV/gems with .env
# - Bundler::ORIGINAL_ENV does not work for resets since it breaks pumas restart handler
# - Allows a custom puma.rb by all containing restart detection here
# - Allows regular ENV to override .env
# - TODO: reset ENV vars that are modified in other ways during app boot
#
# see https://github.com/puma/puma/issues/1258
# test puma restart works: `puts ENV['TEST']` in application.rb, change TEST in .env and then kill -SIGUSR1 the app
reset_dotenv = -> { ENV["SAMSON_ENV_ADDED_VIA_DOTENV"].to_s.split(',').each { |e| ENV.delete(e) } }
reset_dotenv.call

require 'dotenv'
before = ENV.keys
Dotenv.load(Bundler.root.join('.env'))
ENV["SAMSON_ENV_ADDED_VIA_DOTENV"] = (ENV.keys - before).join(",")

if ENV['RAILS_ENV'] == 'test'
  reset_dotenv.call
  Dotenv.load(Bundler.root.join('.env.test'))
end
