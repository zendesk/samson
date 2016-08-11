# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Samson::Tasks::LockCleaner do
  describe ".start" do
    it "starts the timer task" do
      Concurrent::TimerTask.any_instance.expects(:execute)
      Samson::Tasks::LockCleaner.start
    end
  end

  # we cannot really execute this since it leaves the Thread from Concurrent.global_timer_set behind
  # and killing that would break following tests
  describe "execution" do
    it "does nothing on normal execution" do
      Rails.logger.expects(:error).never
      Airbrake.expects(:notify).never
      Samson::Tasks::LockCleaner.new.send(:update, Time.now, nil, nil)
    end

    it "logs when given an exception" do
      Rails.logger.expects(:error).twice
      Airbrake.expects(:notify).with(instance_of(ArgumentError), error_message: 'Samson::Tasks::LockCleaner failed')
      e = begin; raise ArgumentError; rescue; $!; end
      Samson::Tasks::LockCleaner.new.send(:update, Time.now, nil, e)
    end

    it "can run" do
      Samson::Tasks::LockCleaner.new.send(:run)
    end
  end
end
