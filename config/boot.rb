require 'bundler/setup'
require 'bootscale/setup' if ['development', 'test'].include?(ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development')

require "faster_path"
require "faster_path/optional/monkeypatches"
FasterPath.sledgehammer_everything!
