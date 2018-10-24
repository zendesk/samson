# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

def stub_execution
  execution = JobExecution.new('master', job)
  JobQueue.expects(:find_by_id).returns(execution)
  execution
end

describe JobOutputsChannel do
  let(:job) { jobs(:succeeded_test) }
  let(:user) { users(:admin) }
  let(:channel) { JobOutputsChannel.new stub(identifiers: []), nil }

  describe JobOutputsChannel::EventBuilder do
    let(:builder) { JobOutputsChannel::EventBuilder.new(job) }

    it "renders a started" do
      builder.payload(:started, nil).must_equal(title: "Staging deploy - Foo")
    end

    it "renders a finished" do
      builder.payload(:finished, nil).must_equal(
        title: "Staging deploy - Foo",
        notification: "Samson deploy finished:\nFoo / Staging succeeded",
        favicon_path: "/assets/favicons/32x32_green.png"
      )
    end

    it "renders finished for jobs" do
      job.deploy.destroy
      builder.payload(:finished, nil).must_equal(
        title: "Foo deploy (succeeded)"
      )
    end

    it "renders a viewers" do
      builder.payload(:viewers, User.where(id: user.id)).must_equal [{"id" => user.id, "name" => "Admin"}]
    end

    it "renders a append/replave" do
      builder.payload(:append, "foo").must_equal "<span class=\"ansible_none\">foo</span>"
    end
  end

  describe "#subscribed" do
    let(:job) { jobs(:succeeded_test) }

    before do
      channel.stubs(:current_user).returns(user)
      channel.params[:id] = job.id
    end

    it "transmits execution output" do
      execution = stub_execution
      channel.expects(:transmit)
      channel.subscribed
      execution.output.close
      maxitest_wait_for_extra_threads
    end

    it "streams fake output when execution was already finished" do
      channel.expects(:transmit).times(3) # start, message, finished
      channel.subscribed
      maxitest_wait_for_extra_threads
    end

    it "waits for job to start when it is pending" do
      # waiting for job
      job.update_column(:status, 'pending')
      channel.stubs(:sleep).with { sleep 0.05 } # make pauses shorter
      channel.subscribed
      sleep 0.1

      # start job
      channel.expects(:transmit).times(3) # start, message, finished
      job.update_column(:status, 'succeeded')
      maxitest_wait_for_extra_threads
    end
  end

  describe "#unsubscribed" do
    before do
      channel.stubs(:current_user).returns(user)
      channel.params[:id] = "123"
    end

    it "unsubscribes" do
      execution = stub_execution
      execution.viewers.push user
      channel.unsubscribed
      execution.viewers.to_a.size.must_equal 0
    end

    it "noops when execution is finished" do
      channel.unsubscribed
    end
  end
end
