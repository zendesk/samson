require 'samson/job_interpreters'
require_relative './job_ruby_script'

module SamsonRubyScript
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :initialization do
  Samson::JobInterpreters.instance.register JobRubyScript
end

