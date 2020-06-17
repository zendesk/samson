# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::ErrorNotifier do
  describe '.notify' do
    it 'displays debug info if result if a string' do
      callback = ->(*) { 'dummy message' }
      Rails.env.expects(:test?).returns(false)
      error = ArgumentError.new('oh no!')
      error.set_backtrace('foobar')

      Samson::Hooks.with_callback(:error, callback) do
        Samson::ErrorNotifier.notify(error).must_equal 'dummy message'
      end
    end

    it 'raises if in the test environment' do
      Airbrake.expects(:notify) # prevert threadpool creation
      exception = ArgumentError.new('motherofgod')
      exception.set_backtrace(["neatbacktraceyougotthere"])
      e = assert_raises RuntimeError do
        Samson::ErrorNotifier.notify(exception)
      end

      expected_message = "Samson::ErrorNotifier caught exception: motherofgod." \
        " Use Samson::ErrorNotifier.expects(:notify) to silence in tests"
      e.message.must_equal expected_message
      e.backtrace.must_equal ['neatbacktraceyougotthere']
    end

    it 'logs error if not in test environment' do
      Airbrake.expects(:notify) # prevert threadpool creation
      Rails.env.expects(:test?).returns(false)
      error = ArgumentError.new('oh no!')
      error.set_backtrace('foobar')

      Rails.logger.expects(:error).with('ErrorNotifier: ArgumentError - oh no! - foobar')

      Samson::ErrorNotifier.notify(error)
    end

    it 'can log error if exception is a string' do
      Airbrake.expects(:notify) # prevert threadpool creation
      Rails.env.expects(:test?).returns(false)
      Rails.logger.expects(:error).with('ErrorNotifier: Oh no!')

      Samson::ErrorNotifier.notify('Oh no!')
    end
  end

  describe 'user information placeholder' do
    it 'has the same placeholder as what is in 500.html' do
      File.read("public/500.html").must_include(Samson::ErrorNotifier::USER_INFORMATION_PLACEHOLDER)
    end
  end
end
