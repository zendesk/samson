# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe JobExecutionSubscriber do
  it 'sends exceptions to airbrake so other subscribers can continue' do
    Airbrake.expects(:notify)
    execution = JobExecutionSubscriber.new(stub(url: 1)) { raise 'Test' }
    execution.call
  end
end
