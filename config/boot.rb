# frozen_string_literal: true
require 'bundler/setup'

# Work-around for bug in active-support 7.0.8.7, since concurrent-ruby v1.3.5
# stopped requiring logger, read more at https://github.com/rails/rails/issues/54260.
# Remove this require once running on Rails 7.1+.
require 'logger'

raise "ENV clearing failed" if File.expand_path(ENV.fetch("BUNDLE_GEMFILE")) != File.expand_path("Gemfile")

ENV["RAILS_ENV"] = "test" if ARGV[0] == "test" # configure test env early for `bundle exec rails test some_test.rb`
require_relative 'dotenv'

rails_env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
if ['development', 'test'].include?(rails_env)
  require 'bootsnap'
  Bootsnap.setup(
    cache_dir:            'tmp/bootsnap', # Path to your cache
    development_mode:     rails_env == "development",
    load_path_cache:      true, # optimizes the LOAD_PATH with a cache
    compile_cache_iseq:   (rails_env != "test"), # compiles Ruby code into ISeq cache .. breaks coverage reporting
    compile_cache_yaml:   true # compiles YAML into a cache
  )
end
