# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Samson::Application.load_tasks

Rake::Task["default"].clear

Rails::TestTask.new(:default) do |t|
  t.pattern = "{test,plugins/*/test}/**/*_test.rb"
end

namespace :plugins do
  Rails::TestTask.new(:test) do |t|
    t.pattern = "plugins/*/test/**/*_test.rb"
  end
end

namespace :test do
  task js: :environment do
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
    Rails.application.assets.find_asset(file).to_a.first.pathname.to_s
  end
end
