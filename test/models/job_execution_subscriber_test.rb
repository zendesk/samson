require_relative '../test_helper'

describe JobExecutionSubscriber do
  it 'handles exceptions' do
    block = lambda { raise 'Test' }
    execution = JobExecutionSubscriber.new(stub(id: 1), block)
    execution.call
  end
end
