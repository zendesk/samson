require_relative '../../test_helper'
require 'generators/plugin/plugin_generator'

SingleCov.covered! file: 'lib/generators/plugin/plugin_generator.rb'

class PluginGeneratorTest < Rails::Generators::TestCase
  tests PluginGenerator
  destination Rails.root.join('tmp/generators')
  before { prepare_destination }

  it 'generates' do
    run_generator ['FooBar']
  end
end
