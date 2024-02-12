# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe RestartSignalHandler do
  def handle
    @puma_restarted = false
    Signal.expects(:trap).with('SIGUSR1').returns(
      -> do
        @puma_restarted = true
        Thread.current.kill # simulates passing signal to puma and it calling exec
      end
    )
    handler = RestartSignalHandler.listen
    Thread.pass # make sure listener thread starts
    Thread.new { handler.send(:signal_restart) }.join
    maxitest_wait_for_extra_threads
    assert @puma_restarted
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
    RestartSignalHandler.any_instance.expects(:sleep).never
  end

  describe ".listen" do
    it "waits for SIGUSR1 and then kills the underlying server" do
      handle
    end

    it 'fails when Puma handler was never set up' do
      Signal.expects(:trap).with('SIGUSR1').returns('DEFAULT') # returned when no previous trap was set up
      assert_raises RuntimeError, 'Wrong boot order, puma needs to be loaded first' do
        RestartSignalHandler.listen
      end
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

    it 'waits for running tasks' do
      Samson::Periodical.expects(:running_task_count).twice.returns(1, 0)

      RestartSignalHandler.any_instance.expects(:sleep).with(5)
      handle
    end

    it "notifies error notifier when an exception happens and keeps samson running" do
      RestartSignalHandler.any_instance.expects(:wait_for_active_jobs_to_stop).raises("Whoops")
      Samson::ErrorNotifier.expects(:notify)
      silence_thread_exceptions do
        assert_raises(RuntimeError) { handle }.message.must_equal "Whoops"
      end
      maxitest_wait_for_extra_threads # lets signal thread finish
    end

    it 'performs a hard restart if puma takes too long to call exec' do
      Signal.expects(:trap).with('SIGUSR1').returns(-> {})
      handler = RestartSignalHandler.listen
      handler.expects(:sleep)
      handler.expects(:hard_restart)

      handler.send(:signal_restart)
      maxitest_wait_for_extra_threads # lets signal thread finish
    end
  end

  describe ".hard_restart" do
    it 'reports to rollbar and then hard restarts' do
      Signal.expects(:trap).with('SIGUSR1').returns(-> {})
      Thread.expects(:new) # ignore background runner
      handler = RestartSignalHandler.listen

      Samson::ErrorNotifier.expects(:notify).with('Hard restarting, requests will be lost', sync: true)
      handler.expects(:output).with('Error: Sending SIGTERM to hard restart')
      Process.expects(:kill).with(:SIGTERM, Process.pid)
      handler.expects(:sleep)
      handler.expects(:output).with('Error: Sending SIGKILL to hard restart')
      Process.expects(:kill).with(:SIGKILL, Process.pid)

      handler.send(:hard_restart)
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
