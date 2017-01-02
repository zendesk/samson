# frozen_string_literal: true
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# asset gems need to be loaded before app is done loading
ENV['PRECOMPILE'] = '1' if ARGV.include?("test:js") || ARGV.include?("assets:precompile")

require_relative 'config/application'
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

# ideally use --ensure-latest see https://github.com/presidentbeef/brakeman/issues/968
desc 'Run brakeman ... use brakewan -I to add new ignores'
task :brakeman do
  sh "brakecheck brakeman && brakeman --exit-on-warn --format plain --add-engine-path 'plugins/*'"
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop"
end

desc "Analyze for code duplication (large, identical syntax trees) with fuzzy matching."
task :flay do
  require 'flay' # do not require in production

  files = Dir["{config,lib,app,plugins/*/{config,lib,app}}/**/*.{rb,erb}"]
  files -= [
    'plugins/slack_app/app/models/slack_message.rb', # cannot depend on other plugin ... maybe extract
    'app/views/admin/secrets/index.html.erb', # search box
    'plugins/slack_webhooks/app/views/samson_slack_webhooks/_fields.html.erb', # cannot reuse form.input
  ]
  flay = Flay.run([*files, '--mass', '25']) # mass threshold is shown mass / occurrences
  abort "Code duplication found" if flay.report.any?
end

# make parallel_test run all tests and not only core
# gem is not present in staging or production
if Rails.env.development?
  require "parallel_tests/tasks"
  Rake::Task["parallel:test"].clear
  task 'parallel:test' do
    exec "parallel_test test plugins/*/test"
  end
end
