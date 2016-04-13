require_relative '../test_helper'

SingleCov.covered! uncovered: 11

describe StreamsController do
  include OutputBufferSupport

  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:job) { jobs(:running_test) }

  after { kill_extra_threads } # SSE heartbeat never finishes

  as_a_viewer do
    describe "a GET to :show" do
      it "has an initial :started SSE and a :finished SSE" do
        # Override the job retrieval in the streams controller. This way we don't have
        # to stub out all the rest of the JobExecution setup/execute/... flow.
        fake_execution = JobExecution.new("foo", job)
        JobExecution.expects(:find_by_id).returns(fake_execution)

        # make sure that the JobExecution object responds to the pid method
        assert fake_execution.respond_to?(:pid)

        # Get the :show page to open the SSE stream
        get :show, id: job.id

        response.status.must_equal(200)

        wait_for_listeners(fake_execution.output)

        # Write some msgs to our fake TerminalExecutor stream
        fake_execution.output.write("Hello there!\n")
        # Close the stream to denote the job finishing, which will trigger sending the :finished SSE
        fake_execution.output.close

        # Collect the output from the ActiveController::Live::Buffer stream
        lines = []
        response.stream.each { |l| lines << l }

        # Ensure we have at least the :started and :finished SSE msgs
        assert lines.grep(/event: started\ndata:/)
        assert lines.grep(/event: append\ndata:.*Hello there!/)
        assert lines.grep(/event: finished\ndata/)
      end
    end
  end
end
