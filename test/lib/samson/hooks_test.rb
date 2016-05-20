require_relative '../../test_helper'

SingleCov.covered! uncovered: 13 unless defined?(Rake) # rake preloads all plugins

describe Samson::Hooks do
  let(:number_of_plugins) { Dir['plugins/*'].size }
  let(:plugins) { 'nope' }

  describe '.plugins' do
    before do
      Rails.stubs(:env).returns(env.inquiry)
      ENV['PLUGINS'] = plugins

      # Clear cached plugins
      Samson::Hooks.reset_plugins!
    end

    context 'when in the test environment' do
      let(:env) { 'test' }

      it 'returns all the plugins regardless of the PLUGINS env variable' do
        Samson::Hooks.plugins.size.must_equal number_of_plugins
      end
    end

    context 'when in other environments' do
      let(:env) { 'other' }

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

      context 'when the plugins env is set to all' do
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
    end

    context 'when load via local plugin' do
      let(:env) { 'other' }
      let(:plugins) { 'all' }
      let(:path) { '/path/to/samson/plugins/zendesk/lib/samson_zendesk/samson_plugin.rb' }

      it 'return correct plugin name from folder' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'zendesk'
      end
    end

    context 'when load via gem plugin' do
      let(:env) { 'other' }
      let(:plugins) { 'all' }
      let(:path) { '/path/to/gems/ruby-2.2.2/gems/samson_hipchat-0.0.0/lib/samson_hipchat/samson_plugin.rb' }

      it 'return correct plugin name from Gem' do
        Samson::Hooks::Plugin.new(path).name.must_equal 'hipchat'
      end
    end
  end
end
