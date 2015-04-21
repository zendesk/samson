require_relative '../test_helper'

describe Stage do

  subject { stages(:test_staging) }

  before do
    subject.notify_email_address = "test@test.ttt"
    subject.flowdock_flows = [FlowdockFlow.new(name: "test", token: "abcxyz", stage_id: subject.id, enabled: false)]
    subject.save
  end

  describe '#send_flowdock_notifications?' do
    it 'returns that there are no flows with enabled notifications' do
      subject.send_flowdock_notifications?.must_equal(false)
    end

    it 'returns that there are flows with enabled notifications' do
      subject.flowdock_flows.first.update!(enabled: true)
      subject.send_flowdock_notifications?.must_equal(true)
    end
  end
end
