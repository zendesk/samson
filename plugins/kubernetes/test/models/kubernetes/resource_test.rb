# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Resource do
  def assert_pod_deletion
    delete_pod = stub_request(:delete, "http://foobar.server/api/v1/namespaces/name1/pods/pod1").
      to_return(body: '{}')
    yield
    assert_requested delete_pod
  end

  let(:kind) { 'Service' }
  let(:template) do
    {
      kind: kind,
      metadata: {name: 'some-project', namespace: 'pod1'},
      spec: {
        replicas: 2,
        template: {spec: {containers: [{image: "bar"}]}}
      }
    }
  end
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:resource) { Kubernetes::Resource.build(template, deploy_group, autoscaled: false) }
  let(:autoscaled_resource) { Kubernetes::Resource.build(template, deploy_group, autoscaled: true) }
  let(:url) { "http://foobar.server/api/v1/namespaces/pod1/services/some-project" }
  let(:base_url) { File.dirname(url) }

  before { Kubernetes::Resource::Base.any_instance.expects(:sleep).never }

  it "does modify passed in template" do
    content = File.read(File.expand_path("../../../app/models/kubernetes/resource.rb", __dir__))
    reset_code_usages = 3
    content.scan(/@template.*(=|dig_set)/).size.must_equal content.scan('restore_template do').size + reset_code_usages
  end

  describe ".build" do
    it "builds based on kind" do
      Kubernetes::Resource.build({kind: 'Service'}, deploy_group, autoscaled: false).
        class.must_equal Kubernetes::Resource::Service
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

      update = stub_request(:put, url).with { |x| x.body.must_include '"replicas":2'; true }.to_return(body: "{}")
      resource.deploy
      assert_requested update

      # cache was expired
      assert resource.running?
      assert resource.running?
      assert_requested get, times: 2
    end

    it "keeps replicase when autoscaled, to not revert autoscaler changes" do
      get = stub_request(:get, url).to_return(body: {spec: {replicas: 5}}.to_json)
      update = stub_request(:put, url).with { |x| x.body.must_include '"replicas":5'; true }.to_return(body: "{}")

      autoscaled_resource.deploy

      assert_requested update
      assert_requested get
    end

    it "shows errors to users when resource was invalid" do
      stub_request(:get, url).to_return(status: 404)
      stub_request(:post, base_url).to_return(body: '{"message":"Foo.extensions \"app\" is invalid:"}', status: 400)
      assert_raises(Samson::Hooks::UserError) { resource.deploy }.message.must_include "Kubernetes error: Foo"
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

    it "raises SSL exception is raised" do
      stub_request(:get, url).to_raise(OpenSSL::SSL::SSLError)
      assert_raises(OpenSSL::SSL::SSLError) { resource.running? }
    end
  end

  describe "#delete" do
    let!(:delete) { stub_request(:delete, url).to_return(body: "{}") }

    it "deletes" do
      stub_request(:get, url).to_return({body: "{}"}, status: 404)
      resource.delete
      assert_requested delete
    end

    it "fetches after deleting" do
      get = stub_request(:get, url).to_return({body: "{}"}, status: 404)

      resource.delete
      refute resource.running?

      assert_requested delete
      assert_requested get, times: 2
    end

    it "fails when deletion fails" do
      tries = 9
      get = stub_request(:get, url).to_return(body: "{}")
      resource.expects(:sleep).times(tries)

      e = assert_raises(RuntimeError) { resource.delete }
      e.message.must_equal "Unable to delete resource"

      assert_requested delete
      assert_requested get, times: tries + 1
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

  describe "#desired_pod_count" do
    it "reads the value from config" do
      template[:spec] = {replicas: 3}
      resource.desired_pod_count.must_equal 3
    end

    it "expects a constant number of pods when using autoscaling" do
      stub_request(:get, url).to_return(body: {spec: {replicas: 4}}.to_json)
      autoscaled_resource.desired_pod_count.must_equal 4
    end

    it "uses template amount when creating with autoscaling" do
      stub_request(:get, url).to_return(status: 404)
      autoscaled_resource.desired_pod_count.must_equal 2
    end
  end

  describe Kubernetes::Resource::DaemonSet do
    def daemonset_stub(scheduled, misscheduled)
      {
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
      }.to_json
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
        client.expects(:get_daemon_set).raises(KubeException.new(404, 'Not Found', {}))
        client.expects(:get_daemon_set).returns(daemonset_stub(0, 0))
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        resource.deploy
      end

      it "deletes and created when daemonset exists with pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).raises(KubeException.new(404, 'Not Found', {}))
        client.expects(:get_daemon_set).times(4).returns(
          daemonset_stub(1, 1), # running check
          daemonset_stub(1, 1), # after update check #1 ... still running
          daemonset_stub(0, 1), # after update check #2 ... still running
          daemonset_stub(0, 0)  # after update check #3 ... done
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)

        resource.deploy

        # reverts changes to template so create is clean
        refute template[:spec][:template][:spec].key?(:nodeSelector)
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
      {
        spec: {},
        status: {replicas: replica_count}
      }.to_json
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
          template[:spec][:replicas].must_equal 0
        end
        client.expects(:get_deployment).raises(KubeException.new(404, 'Not Found', {}))
        client.expects(:get_deployment).times(3).returns(
          deployment_stub(3),
          deployment_stub(3),
          deployment_stub(0)
        )
        client.expects(:delete_deployment)
        resource.delete
      end
    end

    describe "#revert" do
      it "reverts to previous version" do
        basic = {kind: 'Deployment', metadata: {name: 'some-project', namespace: 'pod1'}}
        previous = basic.deep_merge(metadata: {uid: 'UID'}).freeze

        stub_request(:get, url).to_return(body: "{}")
        stub_request(:put, url).with { |request| request.body.must_equal basic.to_json }

        resource.revert(previous)
      end

      it "deletes when there was no previous version" do
        resource.expects(:delete)
        resource.revert(nil)
      end
    end
  end

  describe Kubernetes::Resource::StatefulSet do
    def deployment_stub(replica_count)
      {
        spec: {},
        status: {replicas: replica_count}
      }.to_json
    end

    let(:kind) { 'StatefulSet' }
    let(:url) { "http://foobar.server/apis/apps/v1beta1/namespaces/pod1/statefulsets/some-project" }

    describe "#client" do
      it "uses the apps client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.apps_client
      end
    end

    describe "#deploy" do
      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        create = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested create
      end

      it "updates when running and using RollingUpdate" do
        template[:spec][:updateStrategy] = "RollingUpdate"
        stub_request(:get, url).to_return(body: "{}")

        update = stub_request(:put, url).to_return(body: "{}")
        resource.deploy
        assert_requested update
      end

      it "patches and deletes pods when using OnDelete (default)" do
        set = {
          spec: {
            replicas: 2,
            selector: {matchLabels: {project: "foo", release: "bar"}},
            template: {spec: {containers: []}}
          }
        }
        stub_request(:get, url).to_return(body: set.to_json)
        assert_pod_deletion do
          update = stub_request(:patch, url).
            with(headers: {"Content-Type" => "application/json-patch+json"}).
            to_return(body: "{}")
          resource.expects(:pods).times(2).returns(
            [{metadata: {creationTimestamp: '1', name: 'pod1', namespace: 'name1'}}],
            [{metadata: {creationTimestamp: '2'}}]
          )
          resource.deploy
          assert_requested update
        end
      end
    end
  end

  describe Kubernetes::Resource::Job do
    let(:kind) { 'Job' }
    let(:url) { "http://foobar.server/apis/batch/v1/namespaces/pod1/jobs/some-project" }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.batch_client
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
        job = {spec: {template: {metadata: {labels: {release_id: 123, deploy_group_id: 234}}}}}
        stub_request(:get, url).to_return({body: job.to_json}, status: 404)
        delete_job = stub_request(:delete, url).to_return(body: '{}')
        create = nil

        query = "http://foobar.server/api/v1/namespaces/pod1/pods?labelSelector=release_id=123,deploy_group_id=234"
        get_pods = stub_request(:get, query).
          to_return(body: '{"items":[{"metadata":{"name":"pod1","namespace":"name1"}}]}')
        assert_pod_deletion do
          create = stub_request(:post, base_url).to_return(body: "{}")
          resource.deploy
        end

        assert_requested get_pods
        assert_requested delete_job
        assert_requested create
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
      let(:old) { {metadata: {resourceVersion: "A", foo: "B"}, spec: {clusterIP: "C"}} }
      let(:expected_body) do
        {
          kind: "Service",
          metadata: {name: "some-project", namespace: "pod1", resourceVersion: "A"},
          spec: {replicas: 2, template: {spec: {containers: [{image: "bar"}]}}, clusterIP: "C"}
        }
      end

      it "creates when missing" do
        stub_request(:get, url).to_return(status: 404)

        request = stub_request(:post, base_url).to_return(body: "{}")
        resource.deploy
        assert_requested request
      end

      it "replaces existing while keeping fields that kubernetes demands" do
        stub_request(:get, url).to_return(body: old.to_json)
        stub_request(:put, url).with(body: expected_body.to_json)
        resource.deploy
      end

      it "keeps whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.foo" do
          stub_request(:get, url).to_return(body: old.to_json)
          stub_request(:put, url).with(body: expected_body.deep_merge(metadata: {foo: "B"}).to_json)
          resource.deploy
        end
      end

      it "ignores unknown whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.nope" do
          stub_request(:get, url).to_return(body: old.to_json)
          stub_request(:put, url).with(body: expected_body.to_json)
          resource.deploy
        end
      end

      it "allows adding whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.nope" do
          template[:metadata][:nope] = "X"
          stub_request(:get, url).to_return(body: old.to_json)
          expected_body[:metadata][:nope] = "X"
          expected_body[:metadata][:resourceVersion] = expected_body[:metadata].delete(:resourceVersion) # has ordering
          stub_request(:put, url).with(body: expected_body.to_json)
          resource.deploy
        end
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
        get = stub_request(:get, url).to_return({body: "{}"}, status: 404)
        delete = stub_request(:delete, url)
        create = stub_request(:post, base_url).to_return(body: "{}")

        resource.deploy

        assert_requested get, times: 2
        assert_requested delete
        assert_requested create
      end

      it "waits for deletion to finish before replacing to avoid duplication errors" do
        resource.expects(:sleep).times(2)

        get = stub_request(:get, url).to_return(
          {body: "{}"},
          {body: "{}"},
          {body: "{}"},
          status: 404
        )
        delete = stub_request(:delete, url)
        create = stub_request(:post, base_url).to_return(body: "{}")

        resource.deploy

        assert_requested get, times: 4
        assert_requested delete
        assert_requested create
      end
    end

    describe "#desired_pod_count" do
      it "is 1" do
        resource.desired_pod_count.must_equal 1
      end
    end
  end
end
