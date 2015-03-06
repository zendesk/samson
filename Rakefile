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
