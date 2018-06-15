# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe StreamsController do
  include OutputBufferSupport

  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  after { maxitest_kill_extra_threads } # SSE heartbeat never finishes

  as_a_viewer do
    describe "#show" do
      context "with a running job" do
        let(:job) { jobs(:running_test) }

        it "has an initial :started SSE and a :finished SSE" do
          # Override the job retrieval in the streams controller. This way we don't have
          # to stub out all the rest of the JobExecution setup/execute/... flow.
          fake_execution = JobExecution.new("foo", job)
          JobQueue.expects(:find_by_id).returns(fake_execution)
          @controller.stubs(:render_to_body).returns("some html")

          # make sure that the JobExecution object responds to the pid method
          assert fake_execution.respond_to?(:pid)

          # wait a bit for stream to open, then generate events
          lines = +''
          t = Thread.new do
            sleep 0.1
            wait_for_listeners(fake_execution.output)

            # Write some msgs to our fake TerminalExecutor stream
            fake_execution.output.write('', :started)
            fake_execution.output.write("Hello there!\n")
            # Close the stream and denote the job finishing, which will trigger sending the :finished SSE
            fake_execution.output.write('', :finished)
            fake_execution.output.close

            # Collect the output from the ActiveController::Live::Buffer stream
            response.stream.each { |l| lines << l }
          end

          # Get the :show page to open the SSE stream
          get :show, params: {id: job.id}

          response.status.must_equal(200)
          t.join

          # Ensure we have at least the :started and :finished SSE msgs
          lines.must_match(/event: started\ndata:/)
          lines.must_match(/event: append\ndata:.*Hello there!/)
          lines.must_match(/event: finished\ndata/)
        end
      end

      context "with a finished job" do
        let(:job) { jobs(:succeeded_test) }
        it "has some :append SSEs and a :finished SSE" do
          # Collect the output from the ActiveController::Live::Buffer stream
          lines = +''
          t = Thread.new do
            sleep 0.1
            response.stream.each { |l| lines << l }
          end

          get :show, params: {id: job.id}

          response.status.must_equal(200)
          t.join

          # Ensure we have at least the :started and :finished SSE msgs
          lines.must_match(/event: append\ndata:.*#{Regexp.escape(job.output.split("\n").first)}/)
          lines.must_match(/event: finished\ndata/)
        end
      end
    end
  end

  # hard to test directly via show, so we get dirty
  describe "#event_handler" do
    let(:job) { jobs(:succeeded_test) }

    before do
      @controller.instance_variable_set(:@current_user, users(:admin))
      @controller.instance_variable_set(:@job, job)
    end

    describe 'started' do
      it "renders deploy header" do
        response = JSON.parse(@controller.send(:event_handler, :started, {}))
        response.fetch("title").must_include "Staging deploy"
        response.fetch("html").must_include "<h1>"
      end

      it "renders jobs header" do
        job.deploy.destroy!
        response = JSON.parse(@controller.send(:event_handler, :started, {}))
        response.fetch("title").must_equal "Foo deploy (succeeded)"
        response.fetch("html").wont_include "<h1>"
        response.fetch("html").must_include "Super Admin executed"
      end
    end

    describe 'finished' do
      before do
        mock_execution = mock
        mock_execution.expects(:viewers).once.returns([users(:admin)])
        @controller.instance_variable_set(:@execution, mock_execution)
      end

      it 'renders successful finished deploy with green favicon' do
        response = JSON.parse(@controller.send(:event_handler, :finished, {}))
        response.fetch('favicon_path').must_equal '/assets/favicons/32x32_green.png'
      end

      it 'renders errored finished deploy with red favicon' do
        @controller.instance_variable_set(:@job, jobs(:failed_test))
        response = JSON.parse(@controller.send(:event_handler, :finished, {}))
        response.fetch('favicon_path').must_equal '/assets/favicons/32x32_red.png'
      end
    end
  end
end
