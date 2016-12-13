# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobExecutionSubscriber do
  it 'sends exceptions to airbrake so other subscribers can continue' do
    Airbrake.expects(:notify)
    block = lambda { raise 'Test' }
    execution = JobExecutionSubscriber.new(stub(url: 1), block)
    execution.call
  end
end
