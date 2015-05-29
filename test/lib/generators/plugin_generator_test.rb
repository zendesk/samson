require 'test_helper'
require 'generators/plugin/plugin_generator'

class PluginGeneratorTest < Rails::Generators::TestCase
  tests PluginGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  test 'generator runs without errors' do
    assert_nothing_raised do
      run_generator ['FooBar']
    end
  end
end
