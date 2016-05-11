require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'yaml'

task default: [:test, :rubocop] # same as .travis.yml

Rake::TestTask.new do |t|
  t.libs << 'test'
end

RuboCop::RakeTask.new
