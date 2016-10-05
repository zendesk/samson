# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Resource do
  let(:kind) { 'Service' }
  let(:template) { {kind: kind, metadata: {name: 'some-project', namespace: 'pod1'}} }
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:resource) { Kubernetes::Resource.build(template, deploy_group) }
  let(:url) { "http://foobar.server/api/v1/namespaces/pod1/services/some-project" }
  let(:base_url) { File.dirname(url) }

  describe ".build" do
    it "builds based on kind" do
      Kubernetes::Resource.build({kind: 'Service'}, deploy_group).class.must_equal Kubernetes::Resource::Service
    end
  end

  describe "#name" do
    it "returns the name" do
      resource.name.must_equal 'some-project'
    end
  end

  describe "#namespace" do
    it "returns the namespace" do
      resource.namespace.must_equal 'pod1'
    end
  end

  describe "#deploy" do
    let(:kind) { 'Deployment' }
    let(:url) { "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/deployments/some-project" }

    it "creates when missing" do
      stub_request(:get, url).to_return(status: 404)

      request = stub_request(:post, base_url).to_return(body: "{}")
      resource.deploy
      assert_requested request
    end

    it "updates existing" do
      stub_request(:get, url).to_return(body: '{}')

      request = stub_request(:put, url).to_return(body: "{}")
      resource.deploy
      assert_requested request
    end
  end

  describe "#running?" do
    it "is true when running" do
      stub_request(:get, url).to_return(body: "{}")
      assert resource.running?
    end

    it "is false when not running" do
      stub_request(:get, url).to_return(status: 404)
      refute resource.running?
    end

    it "raises when a non 404 exception is raised" do
      stub_request(:get, url).to_return(status: 500)
      assert_raises(KubeException) { resource.running? }
    end
  end

  describe "#delete" do
    let!(:request) { stub_request(:delete, url).to_return(body: "{}") }

    it "deletes" do
      resource.delete
      assert_requested request
    end

    it "fetches after deleting" do
      stub_request(:get, url).to_return(status: 404)
      resource.delete
      refute resource.running?
    end
  end

  describe Kubernetes::Resource::DaemonSet do
    def daemonset_stub(scheduled, misscheduled)
      stub(
        to_hash: {
          status: {
            currentNumberScheduled: scheduled,
            numberMisscheduled:     misscheduled
          },
          spec: {
            template: {
              spec: {
                'nodeSelector=' => nil
              }
            }
          }
        }
      )
    end

    let(:kind) { 'DaemonSet' }
    let(:url) { "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/daemonsets/some-project" }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.extension_client
      end
    end

    describe "#deploy" do
      let(:client) { resource.send(:client) }
      before { template[:spec] = {template: {spec: {}}} }

      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end

      it "deletes and created when daemonset exists without pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(2).returns(
          daemonset_stub(0, 0), # initial check
          daemonset_stub(0, 0)  # check for running
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        resource.deploy
      end

      it "deletes and created when daemonset exists with pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(4).returns(
          daemonset_stub(0, 0), # initial check
          daemonset_stub(1, 1),
          daemonset_stub(0, 1),
          daemonset_stub(0, 0)
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        resource.deploy
      end

      it "tells the user what is wrong when the pods never get terminated" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(31).returns(daemonset_stub(0, 1))
        client.expects(:delete_daemon_set).never
        client.expects(:create_daemon_set).never
        e = assert_raises Samson::Hooks::UserError do
          resource.deploy
        end
        e.message.must_include "misscheduled"
      end
    end

    describe "#desired_pod_count" do
      it "reads the value from the server since it is comlicated" do
        stub_request(:get, url).to_return(body: {status: {desiredNumberScheduled: 5}}.to_json)
        resource.desired_pod_count.must_equal 5
      end
    end

    describe "#revert" do
      let(:kind) { 'DaemonSet' }

      it "reverts to previous version" do
        # checks if it exists and then creates the old resource
        stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/bar/daemonsets/foo").
          to_return(status: 404)
        stub_request(:post, "http://foobar.server/apis/extensions/v1beta1/namespaces/bar/daemonsets").
          to_return(body: "{}")

        resource.revert(metadata: {name: 'foo', namespace: 'bar'}, kind: kind)
      end

      it "deletes when there was no previous version" do
        resource.expects(:delete)
        resource.revert(nil)
      end
    end
  end

  describe Kubernetes::Resource::Deployment do
    def deployment_stub(replica_count)
      stub(
        to_hash: {
          spec: {},
          status: {replicas: replica_count}
        }
      )
    end

    let(:kind) { 'Deployment' }
    let(:url) { "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/deployments/some-project" }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.extension_client
      end
    end

    describe "#delete" do
      it "does nothing when deployment is deleted" do
        request = stub_request(:get, url).to_return(status: 404)
        resource.delete
        assert_requested request
      end

      it "waits for pods to terminate before deleting" do
        client = resource.send(:client)
        client.expects(:update_deployment)
        client.expects(:get_deployment).times(3).returns(
          deployment_stub(3),
          deployment_stub(3),
          deployment_stub(0)
        )
        client.expects(:delete_deployment)
        resource.delete
      end
    end

    describe "#desired_pod_count" do
      it "reads the value from config" do
        template[:spec] = {replicas: 3}
        resource.desired_pod_count.must_equal 3
      end
    end

    describe "#revert" do
      it "reverts to previous version" do
        stub_request(:post, "#{url}/rollback").to_return(body: "{}")
        resource.revert(foo: :bar)
      end

      it "deletes when there was no previous version" do
        resource.expects(:delete)
        resource.revert(nil)
      end
    end
  end

  describe Kubernetes::Resource::Job do
    let(:kind) { 'Job' }
    let(:url) { "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/jobs/some-project" }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.extension_client
      end
    end

    describe "#deploy" do
      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end

      it "replaces existing" do
        stub_request(:get, url).to_return(body: '{}')

        delete = stub_request(:delete, url).to_return(body: '{}')
        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy

        assert_requested delete
        assert_requested request
      end
    end

    describe "#desired_pod_count" do
      it "reads the value from config" do
        template[:spec] = {replicas: 3}
        resource.desired_pod_count.must_equal 3
      end
    end

    describe "#revert" do
      it "deletes with previous version since job is already done" do
        resource.expects(:delete)
        resource.revert(foo: :bar)
      end

      it "deletes when there was no previous version" do
        resource.expects(:delete)
        resource.revert(nil)
      end
    end
  end

  describe Kubernetes::Resource::Service do
    describe "#deploy" do
      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end

      it "does not update existing because that is not supported" do
        stub_request(:get, url).to_return(body: '{}')

        resource.deploy
      end
    end

    describe "#revert" do
      it "leaves previous version since we cannot update" do
        resource.revert(foo: :bar)
      end

      it "deletes when there was no previous version" do
        resource.expects(:delete)
        resource.revert(nil)
      end
    end
  end
end
