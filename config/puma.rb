# frozen_string_literal: true
require_relative "boot"

threads ENV.fetch('RAILS_MIN_THREADS', 8), ENV.fetch('RAILS_MAX_THREADS', 250)
preload_app!

bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 9080)}"

# make puma restart reset modified ENV vars and BUNDLE_GEMFILE/RUBYLIB which are set via `bundle exec puma`
# Bundler.original_env will not do since it already has a hardcoded BUNDLE_GEMFILE
# that cannot change when the server is restarted (via exec -> with copied ENV)
# see https://github.com/puma/puma/pull/1282
#
# test basic puma restart works:
# - `puts "T #{ENV['TEST'] ||= "X"}"` after `require_relative 'dotenv'` in `config/boot.rb`
# - boot via `bundle exec puma -C config/puma.rb`
# - change TEST in .env
# - kill -SIGUSR1 <puma-pid>
# - should see `B <nothing>` and `TEST <value from .env>`
#
# test bundler reload works: always checked in `config/boot.rb`
Puma::Runner.prepend(Module.new do
  def before_restart
    ENV.replace(Bundler.clean_env)
    super
  end
end)

# sometimes when puma tries to stop the @server is not even there and then things blow up
# so we just pretend like we stopped it and hope that helps with our hanging restarts issue
# https://github.com/puma/puma/issues/1523
Puma::Single.prepend(Module.new do
  def stop
    super
  rescue NoMethodError
    nil
  end
end)
