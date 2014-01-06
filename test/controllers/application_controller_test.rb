require 'test_helper'

describe ApplicationController do
  describe "#enqueue_job" do
    it "adds a thread" do
      job = stub(:id => 1)

      Deploy.stubs(new: (deploy = stub))
      deploy.stubs(:perform)

      @controller.send(:enqueue_job, job)

      Thread.main[:deploys][job.id].wont_be_nil
      Thread.main[:deploys].each {|_, thread| thread.join}
      Thread.main[:deploys].size.must_equal(0)
    end
  end
end
