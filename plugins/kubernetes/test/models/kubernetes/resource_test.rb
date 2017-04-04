# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Resource do
  let(:kind) { 'Service' }
  let(:template) { {kind: kind, metadata: {name: 'some-project', namespace: 'pod1'}, spec: {}} }
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

      create = stub_request(:post, base_url).to_return(body: "{}")
      resource.deploy
      assert_requested create

      # cache was expired
      get = stub_request(:get, url).to_return(body: "{}")
      assert resource.running?
      assert resource.running?
      assert_requested get, times: 2 # this counts the 404 and the successful request ...
    end

    it "updates existing" do
      get = stub_request(:get, url).to_return(body: '{}')

      update = stub_request(:put, url).to_return(body: "{}")
      resource.deploy
      assert_requested update

      # cache was expired
      assert resource.running?
      assert resource.running?
      assert_requested get, times: 2
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

  describe "#uid" do
    it "returns the uid of the created resource" do
      stub_request(:get, url).to_return(body: {metadata: {uid: 123}}.to_json)
      resource.uid.must_equal 123
    end

    it "returns nil when resource is missing" do
      stub_request(:get, url).to_return(status: 404)
    end
  end

  describe "#prerequisite?" do
    it "is not a prerequisite by default" do
      refute resource.prerequisite?
    end

    it "is a prerequisite when labeled" do
      template[:metadata][:annotations] = {"samson/prerequisite": true}
      assert resource.prerequisite?
    end
  end

  describe "#primary?" do
    it "is primary when it is a primary resource" do
      template[:kind] = "Deployment"
      assert resource.primary?
    end

    it "is not primary when it is a secondary resource" do
      template[:kind] = "Service"
      refute resource.primary?
    end
  end

  describe Kubernetes::Resource::DaemonSet do
    def daemonset_stub(scheduled, misscheduled)
      stub(
        "Daemonset",
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
        client.expects(:get_daemon_set).returns(daemonset_stub(0, 0))
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        resource.deploy
      end

      it "deletes and created when daemonset exists with pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(4).returns(
          daemonset_stub(1, 1), # running check
          daemonset_stub(1, 1), # after update check #1 ... still running
          daemonset_stub(0, 1), # after update check #2 ... still running
          daemonset_stub(0, 0)  # after update check #3 ... done
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
        e.message.must_include "Unable to terminate previous DaemonSet"
      end
    end

    describe "#desired_pod_count" do
      before { template[:spec] = {replicas: 2 } }

      it "reads the value from the server since it is comlicated" do
        stub_request(:get, url).to_return(body: {status: {desiredNumberScheduled: 5}}.to_json)
        resource.desired_pod_count.must_equal 5
      end

      it "retries once when initial state has 0 desired pods" do
        request = stub_request(:get, url).to_return(
          {body: {status: {desiredNumberScheduled: 0}}.to_json},
          body: {status: {desiredNumberScheduled: 5}}.to_json
        )
        resource.desired_pod_count.must_equal 5
        assert_requested request, times: 2
      end

      it "blows up when desired count cannot be found (bad state or no nodes are available)" do
        request = stub_request(:get, url).to_return(body: {status: {desiredNumberScheduled: 0}}.to_json)
        resource.expects(:loop_sleep).once
        assert_raises Samson::Hooks::UserError do
          resource.desired_pod_count
        end
        assert_requested request, times: 2
      end

      it "returns 0 when replicas are 0 to pass deletion deploys" do
        template[:spec][:replicas] = 0
        resource.desired_pod_count.must_equal 0
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
        "Deployment",
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
        client.expects(:update_deployment).with do |template|
          template[:spec].must_equal(replicas: 0)
        end
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
        job = {spec: {selector: {matchLabels: {project: 'foo', release: 'bar'}}}}
        stub_request(:get, url).to_return(body: job.to_json)
        delete_job = stub_request(:delete, url).to_return(body: '{}')
        query = "http://foobar.server/api/v1/namespaces/pod1/pods?labelSelector=project=foo,release=bar"
        get_pods = stub_request(:get, query).
          to_return(body: '{"items":[{"metadata":{"name":"pod1","namespace":"name1"}}]}')
        delete_pod = stub_request(:delete, "http://foobar.server/api/v1/namespaces/name1/pods/pod1").
          to_return(body: '{}')
        create = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy

        assert_requested delete_job
        assert_requested get_pods
        assert_requested delete_pod
        assert_requested create
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

  describe Kubernetes::Resource::ConfigMap do
    # a simple test to make sure basics work
    describe "#deploy" do
      let(:kind) { 'ConfigMap' }
      let(:url) { "http://foobar.server/api/v1/namespaces/pod1/configmaps/some-project" }

      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end
    end
  end

  describe Kubernetes::Resource::Pod do
    let(:kind) { 'Pod' }

    describe "#deploy" do
      let(:url) { "http://foobar.server/api/v1/namespaces/pod1/pods/some-project" }

      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end

      it "replaces when existing" do
        stub_request(:get, url).to_return(body: "{}")
        stub_request(:delete, url)
        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end
    end

    describe "#desired_pod_count" do
      it "is 1" do
        resource.desired_pod_count.must_equal 1
      end
    end
  end
end
