require_relative '../../test_helper'

describe Samson::Hooks do
  let(:number_of_plugins) { 4 }
  let(:plugins) { 'nope' }

  describe '.plugins' do
    before do
      Rails.stubs(:env).returns(env.inquiry)
      ENV['PLUGINS'] = plugins

      # Clear cached plugins
      Samson::Hooks.instance_variable_set('@plugins', nil)
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

      context 'when the plugins env is set to include some plugins' do
        let(:plugins) { 'slack, zendesk' }

        it 'only returns those plugins' do
          Samson::Hooks.plugins.size.must_equal 2
        end
      end
    end
  end
end

