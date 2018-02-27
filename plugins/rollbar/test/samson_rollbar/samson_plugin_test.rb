# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbar do
  describe 'error callback' do
    it 'returns url if sync option is true' do
      mock_data = mock('data')
      mock_url = mock('url')
      mock_config = mock('config')
      mock_exception = mock('exception')

      Rollbar.expects(:error).with(mock_exception, foo: 'bar').returns(mock_data)
      Rollbar.expects(:configuration).returns(mock_config)

      Rollbar::Util.expects(:uuid_rollbar_url).with(mock_data, mock_config).returns(mock_url)

      Samson::Hooks.only_callbacks_for_plugin('rollbar', :error) do
        Samson::Hooks.fire(:error, mock_exception, foo: 'bar', sync: true).must_equal [mock_url]
      end
    end

    it 'calls error if sync option is false/nil' do
      mock_exception = mock
      Rollbar.expects(:error).with(mock_exception, foo: 'bar').once

      Samson::Hooks.only_callbacks_for_plugin('rollbar', :error) do
        Samson::Hooks.fire(:error, mock_exception, foo: 'bar').must_equal [nil]
      end
    end
  end
end
