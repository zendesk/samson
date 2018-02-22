# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobExecutionSubscriber do
  it 'sends exceptions to error notifier so other subscribers can continue' do
    ErrorNotifier.expects(:notify)
    execution = JobExecutionSubscriber.new(stub(url: 1)) { raise 'Test' }
    execution.call
  end
end
