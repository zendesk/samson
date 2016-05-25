require_relative '../test_helper'

SingleCov.covered!

describe RestartSignalHandler do
  def handle
    Signal.expects(:trap).with('SIGUSR1')
    handler = RestartSignalHandler.listen

    Process.expects(:kill).with('SIGUSR2', Process.pid)
    handler.send(:signal)
    sleep 0.1
  end

  def silence_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = old
  end

  before do
    # make sure we never do something silly
    Signal.expects(:trap).never
    Process.expects(:trap).never
    RestartSignalHandler.any_instance.expects(:sleep).never
    JobExecution.clear_registry
    MultiLock.locks.clear
  end

  describe ".listen" do
    around { |t| silence_stdout(&t) }

    it "waits for SIGUSR1 and then kills the underlying server" do
      handle
    end

    it "turns job processing off" do
      JobExecution.enabled = true
      handle
      JobExecution.enabled.must_equal false
    end

    it "waits for running jobs" do
      registry = JobExecution.send(:registry)

      # we call it twice in each iteration
      registry.expects(:active).times(3).returns [stub(id: 123)], [stub(id: 123)], []

      RestartSignalHandler.any_instance.expects(:sleep).with(5)
      handle
    end
  end
end
