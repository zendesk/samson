require 'test_helper'

describe ApplicationController do
  describe "#enqueue_job" do
    it "adds a thread" do
      deploy = stub

      Deploy.stubs(:new => deploy)
      deploy.expects(:perform).with do
        Thread.main[:deploys].size.must_equal(1)
      end

      @controller.send(:enqueue_job, stub(:id => 1))

      Thread.main[:deploys].each(&:join)
      Thread.main[:deploys].size.must_equal(0)
    end
  end
end
