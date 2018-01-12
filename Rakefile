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

Rake::Task['test'].clear
task :test do
  sh "EAGER_LOAD=1 forking-test-runner test plugins/*/test --merge-coverage --quiet"
end

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

# normalize schema after dumping so we do not have a diff
task "db:schema:dump" do
  file = "db/schema.rb"
  schema = File.read(file)
  schema.gsub!(/, options: .* do/, " do")
  schema.gsub!('t.text "output", limit: 4294967295', 't.text "output", limit: 268435455')
  schema.gsub!('t.text "object", limit: 4294967295', 't.text "object", limit: 1073741823')
  File.write(file, schema)
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

  # TODO: make a standalone binding
  # clunky asset finder ... see https://github.com/rails/sprockets-rails/issues/237 for more
  # jquery.js -> <GEM_HOME>/ruby/2.3.0/gems/rails-assets-jquery-2.2.1/app/assets/javascripts/jquery.js
  def resolve_javascript(file)
    paths = Gem::Specification.stubs.map(&:full_gem_path)
    Dir.glob("{#{paths.join(",")}}/app/assets/javascripts/#{file}").first || raise("Could not find #{file}")
  end
end

desc "'Run brakeman, use `bundle exec brakeman --add-engine-path 'plugins/*' -I` to add or remove obsolete ignores"
task :brakeman do
  sh "brakeman --no-pager --add-engine-path 'plugins/*' --ensure-latest"
end

desc 'Scan for gem vulnerabilities'
task :bundle_audit do
  sh "bundle-audit check --update"
end

desc "Run rubocop"
task :rubocop do
  sh "rubocop --parallel"
end

desc "Run rubocop on changed files"
task "rubocop:changed" do
  last_merge = `git log --merges -n1 --pretty=format:%h`.strip
  changed = `git diff #{last_merge} --name-only`.split("\n")
  sh "rubocop #{changed.shelljoin}" if changed.any?
end

desc "Analyze for code duplication (large, identical syntax trees) with fuzzy matching."
task :flay do
  require 'flay' # do not require in production

  files = Dir["{config,lib,app,plugins/*/{config,lib,app}}/**/*.{rb,erb}"]
  files -= [
    'plugins/slack_app/app/models/slack_message.rb', # cannot depend on other plugin ... maybe extract
    'app/views/admin/secrets/index.html.erb', # search box
    'plugins/slack_webhooks/app/views/samson_slack_webhooks/_fields.html.erb', # cannot reuse form.input
    'plugins/pipelines/app/views/samson_pipelines/_stage_show.html.erb', # super simple html
    'app/views/secrets/index.html.erb', # simple html
    'plugins/kubernetes/app/models/kubernetes/deploy_group_role.rb', # similar but slightly different validations
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

Audited.store[:audited_user] = "rake"
