require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::JobService do
  describe "#run!" do
    it "executes" do
      Kubernetes::Executor.any_instance.expects(:execute!)
      ::JobExecution.expects(:start_job).with { |exec| exec.instance_variable_get(:@execution_block).call(exec); true }
      Kubernetes::JobService.new(kubernetes_jobs(:running_test)).run!
    end
  end
end
