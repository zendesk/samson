require 'rspec/core/rake_task'

desc "Run specs"
RSpec::Core::RakeTask.new("spec") do |t|
  t.pattern = "spec/**/*_spec.rb"
end

desc 'Default: run specs.'
task :default => "spec"
