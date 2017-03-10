# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe Stage do
  subject { stages(:test_staging) }

  before { subject.notify_email_address = "test@test.ttt" }

  describe '#send_flowdock_notifications?' do
    it 'returns that there are no flows' do
      subject.send_flowdock_notifications?.must_equal(false)
    end

    it 'returns that there are flows' do
      subject.flowdock_flows = [FlowdockFlow.new(name: "test", token: "abcxyz", stage_id: subject.id)]
      subject.send_flowdock_notifications?.must_equal(true)
    end
  end
end
