# This file is used by Rack-based servers to start the application.
require 'dotenv'
Dotenv.load

## https://github.com/jruby/jruby/wiki/UnlimitedStrengthCrypto
#if RUBY_PLATFORM == "java" && ['development', 'testing', 'staging', ''].include?(ENV["RAILS_ENV"].to_s)
#  java.lang.Class.for_name('javax.crypto.JceSecurity').get_declared_field('isRestricted').tap{|f| f.accessible = true; f.set nil, false}
#end

require ::File.expand_path('../config/environment',  __FILE__)

Rails.application.config.after_initialize do
#  require 'lib/environment_updater'
#  EnvironmentUpdater.new(Project.all).run
end

run Rails.application
