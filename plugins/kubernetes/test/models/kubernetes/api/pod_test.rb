# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Kubernetes::Api::Pod do
  let(:pod_name) { 'test_name' }
  let(:pod_attributes) do
    {
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
        }]
      },
      spec: {
        containers: [
          {name: 'container1'}
        ]
      }
    }
  end
  let(:pod) { Kubernetes::Api::Pod.new(Kubeclient::Resource.new(JSON.parse(pod_attributes.to_json))) }
  let(:pod_with_client) do
    Kubernetes::Api::Pod.new(
      Kubeclient::Resource.new(JSON.parse(pod_attributes.to_json)),
      client: deploy_groups(:pod1).kubernetes_cluster.client
    )
  end

  describe '#live?' do
    it "is live" do
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

    describe 'without conditions' do
      before { pod_attributes[:status].delete :conditions }

      it "is not live" do
        refute pod.live?
      end

      it "is live when it is a finished job" do
        pod_attributes[:status][:phase] = 'Succeeded'
        assert pod.live?
      end
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

  describe "#name" do
    it 'reads ' do
      pod.name.must_equal 'test_name'
    end
  end

  describe "#namespace" do
    it "reads" do
      pod.namespace.must_equal 'the-namespace'
    end
  end

  describe "#deploy_group_id" do
    it 'is the label' do
      pod.deploy_group_id.must_equal 123
    end
  end

  describe "#role_id" do
    it 'is the label' do
      pod.role_id.must_equal 234
    end
  end

  describe "#containers" do
    it 'reads' do
      pod.containers.first.name.must_equal 'container1'
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

    it "reads regular logs" do
      stub_request(:get, log_url).
        and_return(body: "HELLO")
      pod_with_client.logs('some-container').must_equal "HELLO"
    end

    it "reads previous logs when container restarted so we see why it restarted" do
      pod_attributes[:status][:containerStatuses].first[:restartCount] = 1
      stub_request(:get, "#{log_url}&previous=true").
        and_return(body: "HELLO")
      pod_with_client.logs('some-container').must_equal "HELLO"
    end

    it "requests regular logs when previous logs are not available" do
      stub_request(:get, "#{log_url}&previous=true").
        to_raise(KubeException.new('a', 'b', 'c'))
      stub_request(:get, log_url).
        to_return(body: "LOG-1")
      pod_with_client.logs('some-container').must_equal "LOG-1"
    end

    it "does not crash when both log endpoints fails with a 404" do
      stub_request(:get, "#{log_url}&previous=true").
        to_raise(KubeException.new('a', 'b', 'c'))
      stub_request(:get, log_url).
        to_raise(KubeException.new('a', 'b', 'c'))
      pod_with_client.logs('some-container').must_be_nil
    end
  end

  describe "#abnormal_events" do
    let(:events_url) do
      "http://foobar.server/api/v1/namespaces/the-namespace/events?fieldSelector=involvedObject.name=test_name"
    end

    it "is empty when there are no events" do
      stub_request(:get, events_url).to_return(body: {items: []}.to_json)
      pod_with_client.abnormal_events.must_equal []
    end

    it "is empty when there are Normal events" do
      stub_request(:get, events_url).to_return(body: {items: [{type: 'Normal'}]}.to_json)
      pod_with_client.abnormal_events.must_equal []
    end

    it "shows abnormal events" do
      stub_request(:get, events_url).to_return(body: {items: [{type: 'Warning'}]}.to_json)
      pod_with_client.abnormal_events.map(&:type).must_equal ['Warning']
    end
  end
end
