# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# asset gems need to be loaded before app is done loading
ENV['PRECOMPILE'] = '1' if ARGV.include?("test:js") || ARGV.include?("assets:precompile")

require File.expand_path('../config/application', __FILE__)
require "rake/testtask"

Samson::Application.load_tasks

Rake::Task["default"].clear
task default: :test

task :asset_compilation_environment do
  ENV['SECRET_TOKEN'] = 'foo'
  ENV['GITHUB_TOKEN'] = 'foo'

  config = Rails.application.config
  def config.database_configuration
    {}
  end

  ar = ActiveRecord::Base
  def ar.establish_connection
  end
end
Rake::Task['assets:precompile'].prerequisites.unshift :asset_compilation_environment

namespace :plugins do
  Rake::TestTask.new(:test) do |t|
    t.pattern = "plugins/*/test/**/*_test.rb"
    t.warning = false
  end
end

Rake::Task['test'].clear
Rake::TestTask.new(:test) do |t|
  t.pattern = "{test,plugins/*/test}/**/*_test.rb"
  t.warning = false
end

namespace :test do
  task :prepare_js do
    sh "npm install"
    sh "npm run-script jshint"
    sh "npm run-script jshint:plugins"
  end

  task js: [:asset_compilation_environment, :environment] do
    with_tmp_karma_config do |config|
      sh "./node_modules/karma/bin/karma start #{config} --single-run"
    end
  end

  private

  def with_tmp_karma_config
    Tempfile.open('karma.js') do |f|
      f.write ERB.new(File.read('test/karma.conf.js')).result(binding)
      f.flush
      yield f.path
    end
  end

  def resolve_asset(file)
    asset = Rails.application.assets.find_asset(file).to_a.first || raise("Could not find #{file}")
    asset.pathname.to_s
  end
end

desc 'Run brakeman ... use brakewan -I to add new ignores'
task :brakeman do
  begin
    File.symlink('plugins', 'engines')
    sh "brakeman --exit-on-warn --table-width 500"
  ensure
    File.unlink('engines')
  end
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop --display-cop-names"
end
