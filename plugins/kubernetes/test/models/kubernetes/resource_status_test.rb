# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::ResourceStatus do
  def expect_event_request(&block)
    assert_request :get, /events/, to_return: {body: {items: events}.to_json}, &block
  end

  let(:status) do
    Kubernetes::ResourceStatus.new(
      deploy_group: deploy_groups(:pod1),
      role: kubernetes_roles(:app_server),
      resource: resource,
      kind: resource.fetch(:kind),
      start: Time.now.iso8601
    )
  end
  let(:resource) { {kind: 'Pod', metadata: {name: 'foo', namespace: 'default'}, status: {phase: "Running"}} }
  let(:events) { [{lastTimestamp: 30.seconds.from_now.utc.iso8601}] }

  describe "#check" do
    let(:details) do
      status.check
      status.details
    end

    it "is missing without resource" do
      status.instance_variable_set(:@resource, nil)
      details.must_equal "Missing"
    end

    it "is restarted when pod is restarted" do
      resource[:status][:containerStatuses] = [{restartCount: 1, name: "foo", state: {terminated: {reason: "Backoff"}}}]
      details.must_equal "Restarted (foo Backoff)"
    end

    it "is failed when pod is failed" do
      resource[:status][:phase] = "Failed"
      details.must_equal "Failed"
    end

    it "is live when live" do
      resource[:status][:phase] = "Succeeded"
      details.must_equal "Live"
    end

    it "is live when complete and prerequisite" do
      resource[:status][:phase] = "Succeeded"
      status.instance_variable_set(:@prerequisite, true)
      details.must_equal "Live"
    end

    it "is waiting" do
      events.clear
      expect_event_request { details.must_equal "Waiting (Running, Unknown)" }
    end

    it "waits when resources are missing" do
      events[0].merge!(type: "Warning", reason: "FailedScheduling")
      expect_event_request { details.must_equal "Waiting for resources (Running, Unknown)" }
    end

    it "errors when bad events happen" do
      events[0].merge!(type: "Warning", reason: "Boom")
      expect_event_request do
        details.must_equal "Error event"
        assert status.finished
      end
    end

    describe "non-pods" do
      before { resource[:kind] = "NonIgnoredKind" }

      it "knows created non-pods" do
        events.clear
        expect_event_request { details.must_equal "Live" }
      end

      it "ignores known bad events" do
        resource[:kind] = "HorizontalPodAutoscaler"
        events[0].merge!(type: "Warning", reason: "FailedGetMetrics")
        expect_event_request { details.must_equal "Live" }
      end

      it "ignores known bad events for service" do
        resource[:kind] = "Service"
        events[0].merge!(type: "Warning", reason: "FailedToUpdateEndpointSlices")
        expect_event_request { details.must_equal "Live" }
      end

      it "ignores known bad events for statefulset" do
        resource[:kind] = "StatefulSet"
        events[0].merge!(type: "Warning", reason: "RecreatingFailedPod")
        expect_event_request { details.must_equal "Live" }
      end

      describe "with bad event" do
        before { events[0].merge!(type: "Warning", reason: "Boom") }

        it "fails" do
          expect_event_request { details.must_equal "Error event" }
        end

        it "ignores custom known bad events" do
          resource[:metadata][:annotations] = {
            "samson/ignore_events": "Boom"
          }
          expect_event_request { details.must_equal "Live" }
        end

        it "ignores non-matching custom known bad events" do
          resource[:metadata][:annotations] = {
            "samson/ignore_events": "Boing"
          }
          expect_event_request { details.must_equal "Error event" }
        end

        it "ignores karmada sync for policy failed" do
          events[0][:reason] = "ApplyPolicyFailed"
          expect_event_request { details.must_equal "Live" }
        end

        it "ignores karmada syn for sync failed" do
          events[0][:reason] = "SyncFailed"
          expect_event_request { details.must_equal "Live" }
        end
      end
    end
  end

  describe "#events" do
    let(:result) { expect_event_request { status.events } }

    it "finds events" do
      result.size.must_equal 1
    end

    it "ignores previous events" do
      events.first[:lastTimestamp] = 30.seconds.ago.utc.iso8601
      result.size.must_equal 0
    end

    it "does not fail when missing lastTimestamp" do
      events[0][:lastTimestamp] = nil
      events[0][:metadata] = {creationTimestamp: 30.seconds.from_now.utc.iso8601}
      result.size.must_equal 1
    end

    it "sorts" do
      new = 60.seconds.from_now.utc.iso8601
      events.unshift lastTimestamp: new
      events.push lastTimestamp: new
      result.first.must_equal events[1]
    end

    it "shows which cluster the error came from when something goes wrong" do
      e = assert_raises Samson::Hooks::UserError do
        assert_request :get, /events/, to_timeout: [] do
          status.events
        end
      end
      e.message.must_equal "Kubernetes error foo default Pod1: Timed out connecting to server"
    end
  end
end
