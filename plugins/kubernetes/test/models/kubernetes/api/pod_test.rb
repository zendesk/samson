# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Kubernetes::Api::Pod do
  let(:pod_name) { 'test_name' }
  let(:pod_attributes) do
    {
      kind: "Pod",
      metadata: {
        name: pod_name,
        namespace: 'the-namespace',
        labels: {
          deploy_group_id: '123',
          role_id: '234',
        }
      },
      status: {
        phase: "Running",
        conditions: [{type: "Ready", status: "True"}],
        containerStatuses: [{
          restartCount: 0,
          state: {}
        }],
        startTime: start_time,
      },
      spec: {
        containers: [
          {name: 'container1'}
        ]
      }
    }
  end
  let(:pod) { Kubernetes::Api::Pod.new(pod_attributes) }
  let(:pod_with_client) do
    Kubernetes::Api::Pod.new(
      pod_attributes,
      client: deploy_groups(:pod1).kubernetes_cluster.client('v1')
    )
  end
  let(:start_time) { "2017-03-31T22:56:20Z" }
  let(:events_url) do
    "http://foobar.server/api/v1/namespaces/the-namespace/events?fieldSelector=involvedObject.name=test_name,involvedObject.kind=Pod"
  end
  let(:event) { {metadata: {creationTimestamp: start_time}, type: 'Normal'} }
  let(:events) { [event] }

  describe "#live?" do
    it "is done" do
      assert pod.live?
    end

    it "is not live when failed" do
      pod_attributes[:status][:phase] = 'Failed'
      refute pod.live?
    end

    it "is not live when ready is false" do
      pod_attributes[:status][:conditions].first[:status] = 'False'
      refute pod.live?
    end

    it "is not live without ready state" do
      pod_attributes[:status][:conditions].first[:type] = 'Unknown'
      refute pod.live?
    end

    it "is not live without conditions" do
      pod_attributes[:status].delete :conditions
      refute pod.live?
    end

    it "is live when succeeded" do
      pod_attributes[:status][:phase] = "Succeeded"
      assert pod.live?
    end
  end

  describe "#completed?" do
    it "is completed when succeeded" do
      pod_attributes[:status][:phase] = "Succeeded"
      assert pod.completed?
    end

    it "is not completed when not succeeded" do
      pod_attributes[:status][:phase] = "Running"
      refute pod.completed?
    end
  end

  describe "#failed?" do
    it "is not failed" do
      refute pod.failed?
    end

    it "is failed when failed" do
      pod_attributes[:status][:phase] = "Failed"
      assert pod.failed?
    end
  end

  describe "#restarted?" do
    it "is not restarted" do
      refute pod.restarted?
    end

    it "is not restarted without statuses" do
      pod_attributes[:status][:containerStatuses].clear
      refute pod.restarted?
    end

    it "is not restarted when pending and not having conditions yet" do
      pod_attributes[:status].delete :containerStatuses
      refute pod.restarted?
    end

    it "is restarted when restarting" do
      pod_attributes[:status][:containerStatuses][0][:restartCount] = 1
      assert pod.restarted?
    end
  end

  describe "#container_names" do
    it 'reads' do
      pod.container_names.must_equal ['container1']
    end

    it "finds modern json init containers" do
      pod_attributes[:spec][:initContainers] = [{name: "foo"}]
      pod.container_names.must_equal ['container1', 'foo']
    end

    it "finds old json init containers" do
      pod_attributes[:metadata][:annotations] = {'pod.beta.kubernetes.io/init-containers': '[{"name": "foo"}]'}
      pod.container_names.must_equal ['container1', 'foo']
    end
  end

  describe "#reason" do
    it "is unknown when unknown" do
      pod.reason.must_equal "Unknown"
    end

    it "is unknown when missing" do
      pod_attributes[:status].delete :containerStatuses
      pod.reason.must_equal "Unknown"
    end

    it "shows containerStatuses reason" do
      pod_attributes[:status][:containerStatuses][0][:state] = {waiting: {reason: "ContainerCreating"}}
      pod.reason.must_equal "ContainerCreating"
    end

    it "shows conditions reason" do
      pod_attributes[:status][:conditions][0][:reason] = "Borked"
      pod.reason.must_equal "Borked"
    end

    it "works without conditions" do
      pod_attributes[:status].delete :conditions
      pod.reason.must_equal "Unknown"
    end

    it "shows unique reasons" do
      pod_attributes[:status][:containerStatuses] = Array.new(2).map do
        {state: {waiting: {reason: "ContainerCreating"}}}
      end
      pod.reason.must_equal "ContainerCreating"
    end
  end

  describe "#logs" do
    let(:log_url) { "http://foobar.server/api/v1/namespaces/the-namespace/pods/test_name/log?container=some-container" }

    it "streams regular logs" do
      stub_request(:get, "#{log_url}&follow=true").
        and_return(body: "HELLO\nWORLD\n")
      pod_with_client.logs('some-container', 10.seconds.from_now).must_equal "HELLO\nWORLD\n"
    end

    it "fetches previous logs when current logs are not available" do
      stub_request(:get, "#{log_url}&follow=true").
        to_raise(Kubeclient::HttpError.new('a', 'b', 'c'))
      stub_request(:get, "#{log_url}&previous=true").
        and_return(body: "HELLO")
      pod_with_client.logs('some-container', 10.seconds.from_now).must_equal "HELLO"
    end

    describe "with restarted pod" do
      def log_url
        "#{super}&previous=true"
      end

      before do
        pod_attributes[:status][:containerStatuses].first[:restartCount] = 1
        pod_with_client.stubs(:sleep)
      end

      it "reads previous logs so we see why it restarted" do
        logs = stub_request(:get, log_url).and_return(body: "HI")
        pod_with_client.logs('some-container', 10.seconds.from_now).must_equal "HI"
        assert_requested logs, times: 1
      end

      it "retries fetching previous logs if they were not yet available" do
        logs = stub_request(:get, log_url).and_return([{body: "Unable to retrieve container logs foo"}, {body: "HI"}])
        pod_with_client.logs('some-container', 10.seconds.from_now).must_equal "HI"
        assert_requested logs, times: 2
      end

      it "fails fetching previous logs if they are never available" do
        logs = stub_request(:get, log_url).and_return(body: "Unable to retrieve container logs foo")
        pod_with_client.logs('some-container', 10.seconds.from_now).must_equal "Unable to retrieve container logs foo"
        assert_requested logs, times: 3
      end
    end

    it "does not crash when both log endpoints fails with a 404" do
      stub_request(:get, "#{log_url}&follow=true").
        to_raise(Kubeclient::HttpError.new('a', 'b', 'c'))
      stub_request(:get, "#{log_url}&previous=true").
        to_raise(Kubeclient::HttpError.new('a', 'b', 'c'))
      pod_with_client.logs('some-container', 10.seconds.from_now).must_be_nil
    end

    it "notifies the user when streaming times out" do
      pod_with_client.expects(:timeout_logs).raises(Timeout::Error)
      stub_request(:get, "#{log_url}&follow=true").
        and_return(body: "HELLO\n")
      pod_with_client.logs('some-container', 10.seconds.from_now).must_equal "... log streaming timeout"
    end

    it "does not wait when timeout has already passed" do
      pod_with_client.expects(:timeout_logs).never
      stub_request(:get, log_url).
        and_return(body: "HELLO\n")
      pod_with_client.logs('some-container', 1.seconds.from_now).must_equal "HELLO\n"
    end
  end

  describe "#events_indicate_failure?" do
    def events_indicate_failure?
      pod_with_client.instance_variable_set(:@events, events)
      pod_with_client.events_indicate_failure?
    end

    it "is true" do
      assert events_indicate_failure?
    end

    it "is false when there are no events" do
      events.clear
      refute events_indicate_failure?
    end

    describe "probe failures" do
      before do
        event.merge!(type: 'Warning', reason: 'Unhealthy', message: +"Readiness probe failed: Get ", count: 1)
      end

      it "is false with single Readiness event" do
        refute events_indicate_failure?
      end

      it "fails with unknown probe failure" do
        assert event[:message].sub!('Readiness', 'Crazyness')
        e = assert_raises(RuntimeError) { events_indicate_failure? }
        e.message.must_equal "Unknown probe Crazyness probe failed: Get "
      end

      describe "with multiple Readiness failures" do
        before { event[:count] = 20 }

        it "is true" do
          assert events_indicate_failure?
        end

        it "is false with less then threshold" do
          pod_attributes[:spec][:containers][0][:readinessProbe] = {failureThreshold: 30}
          refute events_indicate_failure?
        end
      end

      it "is true with multiple Liveness events" do
        assert event[:message].sub!('Readiness', 'Liveness')
        event[:count] = 20
        assert events_indicate_failure?
      end
    end

    describe "HorizontalPodAutoscaler with failures we don't care about" do
      before do
        event.merge!(kind: 'HorizontalPodAutoscaler', type: 'Warning')
      end

      it "ignores failing to get metrics" do
        event[:reason] = 'FailedGetMetrics'

        refute events_indicate_failure?, 'FailedGetMetrics must not be recognized as failures'
      end

      it "ingores failures to scale" do
        event[:reason] = 'FailedRescale'

        refute events_indicate_failure?, 'FailedRescale must not be recognized as failures'
      end

      it "does not ignore an unknown HPA event" do
        event[:reason] = 'SomeOtherFailure'

        assert events_indicate_failure?, 'Events we dont explicitly ignore must be recognized as failures'
      end
    end
  end

  describe "#waiting_for_resources?" do
    def waiting_for_resources?
      pod_with_client.instance_variable_set(:@events, events)
      pod_with_client.waiting_for_resources?
    end

    it "is not waiting when all is good" do
      refute waiting_for_resources?
    end

    it "is not waiting when bad" do
      event[:type] = "Warning"
      refute waiting_for_resources?
    end

    it "is not waiting when bad and FailedScheduling" do
      event[:type] = "Warning"
      events << event.dup.merge(reason: "FailedScheduling")
      refute waiting_for_resources?
    end

    it "is waiting when bad event is FailedScheduling" do
      event[:type] = "Warning"
      event[:reason] = "FailedScheduling"
      assert waiting_for_resources?
    end

    it "is waiting when bad event is FailedAttachVolume" do
      event[:type] = "Warning"
      event[:reason] = "FailedAttachVolume"
      assert waiting_for_resources?
    end
  end
end
