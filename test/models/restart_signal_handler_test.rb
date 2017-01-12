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
      JobExecution.enabled.must_equal true
      handle
      JobExecution.enabled.must_equal false
    end

    it "waits for running jobs" do
      job_queue = JobExecution.send(:job_queue)
      job_exec = stub(id: 123, pid: 444, pgid: 5555, descriptor: 'Job thingy')

      # we call it twice in each iteration
      job_queue.expects(:active).times(2).returns [job_exec], []

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
end
