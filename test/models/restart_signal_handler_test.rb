# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe RestartSignalHandler do
  def handle
    Signal.expects(:trap).with('SIGUSR1')
    handler = RestartSignalHandler.listen

    Process.expects(:kill).with('SIGUSR2', Process.pid)
    handler.send(:signal_restart)
    sleep 0.1
  end

  def silence_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = old
  end

  with_job_execution

  before do
    # make sure we never do something silly
    Signal.expects(:trap).never
    Process.expects(:trap).never
    RestartSignalHandler.any_instance.expects(:sleep).never
  end

  describe ".listen" do
    it "waits for SIGUSR1 and then kills the underlying server" do
      handle
    end

    it "turns job processing off" do
      JobQueue.enabled.must_equal true
      handle
      JobQueue.enabled.must_equal false
    end

    it "waits for running jobs" do
      job_exec = stub(id: 123, pid: 444, pgid: 5555, descriptor: 'Job thingy')

      # we call it twice in each iteration
      JobQueue.expects(:executing).times(2).returns [job_exec], []

      RestartSignalHandler.any_instance.expects(:sleep).with(5)
      handle
    end

    it "notifies airbrake when an exception happens and keeps samson running" do
      RestartSignalHandler.any_instance.expects(:wait_for_active_jobs_to_finish).raises("Whoops")
      Airbrake.expects(:notify)
      assert_raises(RuntimeError) { handle }.message.must_equal "Whoops"

      Process.kill('SIGUSR2', Process.pid) # satisfy expect from `before`
    end
  end

  describe ".after_restart" do
    before do
      csv_exports(:pending).update_column(:status, 'started')
    end

    it "turns job-execution on" do
      RestartSignalHandler.after_restart
      JobQueue.enabled.must_equal true
    end

    it "cancels running jobs" do
      RestartSignalHandler.after_restart
      jobs(:running_test).status.must_equal "cancelled"
    end

    it "starts pending jobs" do
      jobs(:running_test).update_column(:status, 'pending')
      JobQueue.expects(:perform_later)
      RestartSignalHandler.after_restart
    end

    it "starts pending csv_export_jobs" do
      csv_exports(:pending).update_column(:status, 'pending')
      JobQueue.expects(:perform_later)
      RestartSignalHandler.after_restart
    end
  end
end
