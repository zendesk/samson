# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonAirbrake do
  describe '.exception_debug_info' do
    it 'returns error debug info' do
      notice = {'id' => '1'}
      SamsonAirbrake::SamsonPlugin.exception_debug_info(notice).must_equal 'Error https://airbrake.io/locate/1'
    end

    it 'returns nil if airbrake fails' do
      SamsonAirbrake::SamsonPlugin.exception_debug_info(nil).must_be_nil
    end

    it 'returns airbrake id error if there is no id' do
      SamsonAirbrake::SamsonPlugin.exception_debug_info({}).must_equal 'Airbrake did not return an error id'
    end
  end

  describe 'exception callback' do
    it 'shows debug info and calls notify_sync if sync is true' do
      mock_notice = mock
      mock_exception = mock
      Airbrake.expects(:notify_sync).with(mock_exception, foo: 'bar').once.returns(mock_notice)
      SamsonAirbrake::SamsonPlugin.expects(:exception_debug_info).with(mock_notice).once

      Samson::Hooks.only_callbacks_for_plugin('airbrake', :error) do
        Samson::Hooks.fire(:error, mock_exception, foo: 'bar', sync: true)
      end
    end

    it 'calls notify if sync is false/nil' do
      mock_exception = mock
      Airbrake.expects(:notify).with(mock_exception, foo: 'bar').once

      Samson::Hooks.only_callbacks_for_plugin('airbrake', :error) do
        Samson::Hooks.fire(:error, mock_exception, foo: 'bar')
      end
    end
  end
end
