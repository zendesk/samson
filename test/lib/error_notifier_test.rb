# frozen_string_literal: true
#
require_relative '../test_helper'

SingleCov.covered!

describe ErrorNotifier do
  describe '.notify' do
    it 'displays debug info if result if a string' do
      callback = ->(*) { 'dummy message' }
      Rails.env.expects(:test?).returns(false)
      error = ArgumentError.new('oh no!')
      error.set_backtrace('foobar')

      Samson::Hooks.with_callback(:error, callback) do
        ErrorNotifier.notify(error).must_equal 'dummy message'
      end
    end

    it 'raises if in the test environment' do
      exception = ArgumentError
      assert_raises exception do
        ErrorNotifier.notify(exception)
      end
    end

    it 'logs error if not in test environment' do
      Rails.env.expects(:test?).returns(false)
      error = ArgumentError.new('oh no!')
      error.set_backtrace('foobar')

      Rails.logger.expects(:error).with('ErrorNotifier: ArgumentError - oh no! - foobar')

      ErrorNotifier.notify(error)
    end
  end

  describe 'user information placeholder' do
    it 'has the same placeholder as what is in 500.html' do
      File.read("public/500.html").must_include(ErrorNotifier::USER_INFORMATION_PLACEHOLDER)
    end
  end
end
