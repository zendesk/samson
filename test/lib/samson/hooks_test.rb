# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: 12

describe Samson::Hooks do
  let(:number_of_plugins) { Dir['plugins/*'].size }
  let(:plugins) { nil }

  describe '.plugins' do
    around do |test|
      with_env(PLUGINS: plugins) do
        Samson::Hooks.instance_variable_set(:@plugins, nil)
        Samson::Hooks.instance_variable_set(:@plugin_list, nil)
        test.call
        Samson::Hooks.instance_variable_set(:@plugins, nil)
        Samson::Hooks.instance_variable_set(:@plugin_list, nil)
      end
    end

    context 'when the plugins env is not set to anything' do
      it 'returns no plugins by default' do
        Samson::Hooks.plugins.size.must_equal 0
      end
    end

    context 'when the plugins env is set to all' do
      let(:plugins) { 'all' }

      it 'returns all the plugins' do
        Samson::Hooks.plugins.size.must_equal number_of_plugins
      end
    end

    context 'when ignoring plugins' do
      let(:plugins) { 'all,-kubernetes,-zendesk' }

      it 'returns the plugins that were not disabled' do
        Samson::Hooks.plugins.size.must_equal(number_of_plugins - 2)
        refute Samson::Hooks.active_plugin?('kubernetes')
        refute Samson::Hooks.active_plugin?('zendesk')
        assert Samson::Hooks.active_plugin?('env')
      end
    end

    context 'when the plugins env is set to include some plugins' do
      let(:plugins) { 'kubernetes, zendesk' }

      it 'only returns those plugins' do
        Samson::Hooks.plugins.size.must_equal 2
        assert Samson::Hooks.active_plugin?('kubernetes')
        assert Samson::Hooks.active_plugin?('zendesk')
        refute Samson::Hooks.active_plugin?('env')
      end
    end

    context 'when load via local plugin' do
      let(:plugins) { 'all' }
      let(:path) { '/path/to/samson/plugins/zendesk/lib/samson_zendesk/samson_plugin.rb' }

      it 'return correct plugin name from folder' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'zendesk'
      end
    end

    context 'when load via gem plugin' do
      let(:plugins) { 'all' }
      let(:path) { '/path/to/gems/ruby-2.2.2/gems/samson_hipchat-0.0.0/lib/samson_hipchat/samson_plugin.rb' }

      it 'return correct plugin name from Gem' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'hipchat'
      end
    end
  end
end
