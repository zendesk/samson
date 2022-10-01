# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 4

describe SamsonSentry do
  describe 'error callback' do
    let(:exception) { mock('exception') }

    it 'reports error' do
      Sentry.expects(:capture_exception).once
      Samson::Hooks.fire(:error, exception, foo: 'bar', sync: true)
    end
  end
end
