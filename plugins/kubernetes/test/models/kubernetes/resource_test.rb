# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Resource do
  def assert_pods_lookup(&block)
    assert_request(
      :get,
      "#{origin}/api/v1/namespaces/pod1/pods?labelSelector=release_id=123,deploy_group_id=234",
      to_return: {body: '{"items":[{"metadata":{"name":"pod1","namespace":"name1"}}]}'},
      &block
    )
  end

  def assert_pod_deletion(&block)
    assert_request(:delete, "#{origin}/api/v1/namespaces/name1/pods/pod1", to_return: {body: '{}'}, &block)
  end

  def autoscaled!
    resource.instance_variable_set(:@autoscaled, true)
  end

  def delete_resource!
    resource.instance_variable_set(:@delete_resource, true)
  end

  def assert_create_and_delete_requests(**args, &block)
    assert_request(:get, url, to_return: [{body: '{}'}, {status: 404}]) do
      assert_request(:delete, url, to_return: {body: '{}'}) do
        assert_request(:post, base_url, **args, to_return: {body: '{}'}, &block)
      end
    end
  end

  let(:origin) { "http://foobar.server" }
  let(:template) do
    {
      kind: kind,
      apiVersion: api_version,
      metadata: {name: 'some-project', namespace: 'pod1'},
      spec: {
        replicas: 2,
        template: {
          spec: {containers: [{image: "bar"}]},
          metadata: {labels: {release_id: 123, deploy_group_id: 234}}
        }
      }
    }
  end
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:resource) do
    Kubernetes::Resource.build(template, deploy_group, autoscaled: false, delete_resource: false)
  end
  let(:base_url) { File.dirname(url) }
  let(:url) do
    path = (api_version == 'v1' ? "api/#{api_version}" : "apis/#{api_version}")
    endpoint = "#{origin}/#{path}"
    "#{endpoint}/namespaces/pod1/#{kind.downcase.pluralize}/some-project"
  end

  before { Kubernetes::Resource::Base.any_instance.stubs(:sleep) }

  describe Kubernetes::Resource::Base do
    let(:kind) { 'ConfigMap' } # Type that falls back to Base
    let(:api_version) { 'v1' }

    it "does not modify passed in template" do
      content = File.read(File.expand_path("../../../app/models/kubernetes/resource.rb", __dir__))
      restore_usages = content.scan('restore_template do').size
      template_modified = content.scan(/@template.*(=|dig_set|delete)/).size
      template_modified.must_equal restore_usages + 4
    end

    it "falls back to using VersionedUpdate" do
      Kubernetes::Resource.build({kind: 'ConfigMap'}, deploy_group, autoscaled: false, delete_resource: false).
        class.must_equal Kubernetes::Resource::VersionedUpdate
    end

    describe ".build" do
      it "builds based on kind" do
        Kubernetes::Resource.build({kind: 'Service'}, deploy_group, autoscaled: false, delete_resource: false).
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

      it "does not blow up if namespace is nil" do
        template[:metadata].delete(:namespace)
        resource.namespace.must_equal nil
      end
    end

    describe "#deploy" do
      let(:kind) { 'Deployment' }
      let(:api_version) { 'extensions/v1beta1' }
      let(:url) { "#{origin}/apis/extensions/v1beta1/namespaces/pod1/deployments/some-project" }

      it "creates when missing" do
        assert_request(:get, url, to_return: [{status: 404}, {body: "{}"}]) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end

          # not auto-cached
          assert resource.exist?
          assert resource.exist?
        end
      end

      it "updates existing" do
        assert_request(:get, url, to_return: {body: "{}"}, times: 2) do
          args = ->(x) { x.body.must_include '"replicas":2'; true }
          assert_request(:put, url, to_return: {body: "{}"}, with: args) do
            resource.deploy
          end

          # not auto-cached
          assert resource.exist?
          assert resource.exist?
        end
      end

      it "keeps replicase when autoscaled, to not revert autoscaler changes" do
        assert_request(:get, url, to_return: {body: {spec: {replicas: 5}}.to_json}) do
          args = ->(x) { x.body.must_include '"replicas":5'; true }
          assert_request(:put, url, to_return: {body: "{}"}, with: args) do
            autoscaled!
            resource.deploy
          end
        end
      end

      it "shows errors to users when resource was invalid" do
        assert_request(:get, url, to_return: {status: 404}) do
          error = '{"message":"Foo.extensions \"app\" is invalid:"}'
          assert_request(:post, base_url, to_return: {body: error, status: 400}) do
            e = assert_raises(Samson::Hooks::UserError) { resource.deploy }
            e.message.must_include "Kubernetes error some-project pod1 Pod1: Foo"
          end
        end
      end

      describe "updating matchLabels" do
        before { template[:spec][:selector] = {matchLabels: {foo: "bar"}} }

        it "explains why it is a bad idea" do
          old = {spec: {selector: {matchLabels: {foo: "baz"}}}}
          assert_request(:get, url, to_return: {body: old.to_json}) do
            e = assert_raises(Samson::Hooks::UserError) { resource.deploy }
            e.message.must_equal(
              "Updating spec.selector.matchLabels from {:foo=>\"baz\"} to {:foo=>\"bar\"} " \
              "can only be done by deleting and redeploying or old pods would not be deleted."
            )
          end
        end

        it "allows removing a label" do
          old = {spec: {selector: {matchLabels: {foo: "bar", bar: "baz"}}}}
          assert_request(:get, url, to_return: {body: old.to_json}) do
            assert_request(:put, url, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end

        it "allows it for blue-green deploys" do
          template[:spec][:selector][:matchLabels][:blue_green] = "blue"
          assert_request(:get, url, to_return: {body: "{}"}) do
            assert_request(:put, url, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      describe "delete_resource" do
        before { delete_resource! }

        it "deletes when delete was requested" do
          assert_request(:get, url, to_return: {body: "{}"}) do
            resource.expects(:delete)
            resource.deploy
          end
        end

        it "does nothing when delete was requested but was not existing" do
          assert_request(:get, url, to_return: {status: 404}) do
            resource.deploy
          end
        end
      end
    end

    describe "#create" do
      it "shows error location when create returns 404" do
        assert_request(:post, base_url, to_return: {status: 404}) do
          assert_raises(Samson::Hooks::UserError) { resource.send(:create) }
        end
      end
    end

    describe "#exist?" do
      it "is true when existing" do
        assert_request(:get, url, to_return: {body: "{}"}) do
          assert resource.exist?
        end
      end

      it "is false when not existing" do
        assert_request(:get, url, to_return: {status: 404}) do
          refute resource.exist?
        end
      end

      it "raises when a non 404 exception is raised" do
        assert_request(:get, url, to_return: {status: 500}, times: 4) do
          assert_raises(Kubeclient::HttpError) { resource.exist? }
        end
      end

      it "raises SSL exception is raised" do
        assert_request(:get, url, to_raise: OpenSSL::SSL::SSLError, times: 4) do
          assert_raises(OpenSSL::SSL::SSLError) { resource.exist? }
        end
      end
    end

    describe "#delete" do
      around { |t| assert_request(:delete, url, to_return: {body: "{}"}, &t) }

      it "deletes" do
        assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
          resource.delete
        end
      end

      it "fetches after deleting" do
        assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
          resource.delete
          refute resource.exist?
        end
      end

      it "fails when deletion fails" do
        tries = 9
        assert_request(:get, url, to_return: {body: "{}"}, times: tries + 1) do
          resource.expects(:sleep).times(tries)

          e = assert_raises(RuntimeError) { resource.delete }
          e.message.must_equal "Unable to delete resource (some-project pod1 Pod1)"
        end
      end
    end

    describe "#uid" do
      it "returns the uid of the created resource" do
        assert_request(:get, url, to_return: {body: {metadata: {uid: 123}}.to_json}) do
          resource.uid.must_equal 123
        end
      end

      it "returns nil when resource is missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          resource.uid.must_be_nil
        end
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

    describe "#desired_pod_count" do
      it "reads the value from config" do
        template[:spec] = {replicas: 3}
        resource.desired_pod_count.must_equal 3
      end

      it "expects a constant number of pods when using autoscaling" do
        assert_request(:get, url, to_return: {body: {spec: {replicas: 4}}.to_json}) do
          autoscaled!
          resource.desired_pod_count.must_equal 4
        end
      end

      it "uses template amount when creating with autoscaling" do
        assert_request(:get, url, to_return: {status: 404}) do
          autoscaled!
          resource.desired_pod_count.must_equal 2
        end
      end

      it "is 1 when not set for primary" do
        template[:spec].delete :replicas
        resource.desired_pod_count.must_equal 1
      end

      it "is 0 when not set for config" do
        template.delete :spec
        resource.desired_pod_count.must_equal 0
      end

      it "is 0 when pod is deleted" do
        delete_resource!
        resource.desired_pod_count.must_equal 0
      end
    end

    describe "#request" do
      it "returns response" do
        stub_request(:get, "http://foobar.server/api/v1/configmaps/pods").to_return body: '{"foo": "bar"}'
        resource.send(:request, :get, :pods).must_equal foo: "bar"
      end

      it "shows nice error message when user uses the wrong apiVersion" do
        template[:apiVersion] = 'extensions/v1beta1'
        e = assert_raises(Samson::Hooks::UserError) { resource.send(:request, :get, :pods) }
        e.message.must_equal(
          "apiVersion extensions/v1beta1 does not support ConfigMap. Check kubernetes docs for correct apiVersion"
        )
      end
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
            metadata: {
              labels: {release_id: 123, deploy_group_id: 234}
            },
            spec: {
              nodeSelector: nil
            }
          }
        }
      }
    end

    let(:kind) { 'DaemonSet' }
    let(:api_version) { 'extensions/v1beta1' }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.client('extensions/v1beta1')
      end
    end

    describe "#deploy" do
      let(:client) { resource.send(:client) }
      before { template[:spec] = {template: {spec: {}}} }

      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "deletes and created when daemonset exists without pods" do
        client.expects(:get_daemon_set).raises(Kubeclient::ResourceNotFoundError.new(404, 'Not Found', {}))
        client.expects(:get_daemon_set).returns(daemonset_stub(0, 0))
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        resource.deploy
      end

      it "deletes and created when daemonset exists with pods" do
        client.expects(:get_daemon_set).raises(Kubeclient::ResourceNotFoundError.new(404, 'Not Found', {}))
        client.expects(:update_daemon_set).returns(daemonset_stub(1, 1))
        client.expects(:get_daemon_set).times(4).returns(
          daemonset_stub(1, 1), # existing check
          daemonset_stub(1, 1), # after update check #1 ... still existing
          daemonset_stub(0, 1), # after update check #2 ... still existing
          daemonset_stub(0, 0)  # after update check #3 ... done
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)

        assert_pods_lookup do
          assert_pod_deletion do
            resource.deploy
          end
        end

        # reverts changes to template so create is clean
        refute template[:spec][:template][:spec].key?(:nodeSelector)
      end
    end

    describe "#desired_pod_count" do
      before { template[:spec] = {replicas: 2} }

      it "reads the value from the server since it is comlicated" do
        assert_request(:get, url, to_return: {body: {status: {desiredNumberScheduled: 5}}.to_json}) do
          resource.desired_pod_count.must_equal 5
        end
      end

      it "retries once when initial state has 0 desired pods" do
        assert_request(
          :get,
          url,
          to_return: [
            {body: {status: {desiredNumberScheduled: 0}}.to_json},
            {body: {status: {desiredNumberScheduled: 5}}.to_json}
          ]
        ) { resource.desired_pod_count.must_equal 5 }
      end

      it "blows up when desired count cannot be found (bad state or no nodes are available)" do
        assert_request(:get, url, to_return: {body: {status: {desiredNumberScheduled: 0}}.to_json}, times: 3) do
          resource.expects(:sleep).times(2)
          assert_raises Samson::Hooks::UserError do
            resource.desired_pod_count
          end
        end
      end

      it "is 0 when deleted" do
        delete_resource!
        resource.desired_pod_count.must_equal 0
      end
    end

    describe "#revert" do
      let(:kind) { 'DaemonSet' }
      let(:api_version) { 'extensions/v1beta1' }
      let(:base_url) { "#{origin}/apis/extensions/v1beta1/namespaces/bar/daemonsets" }

      it "reverts to previous version" do
        # checks if it exists and then creates the old resource
        assert_request(:get, "#{base_url}/foo", to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.revert(metadata: {name: 'foo', namespace: 'bar'}, kind: kind, apiVersion: api_version)
          end
        end
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
      }
    end

    let(:kind) { 'Deployment' }
    let(:api_version) { 'extensions/v1beta1' }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.client('extensions/v1beta1')
      end
    end

    describe "#delete" do
      it "does nothing when deployment is deleted" do
        assert_request(:get, url, to_return: {status: 404}) do
          resource.delete
        end
      end

      it "waits for pods to terminate before deleting" do
        client = resource.send(:client)
        client.expects(:update_deployment).with do |template|
          template[:spec][:replicas].must_equal 0
        end
        client.expects(:get_deployment).raises(Kubeclient::ResourceNotFoundError.new(404, 'Not Found', {}))
        client.expects(:get_deployment).times(3).returns(
          deployment_stub(3),
          deployment_stub(3),
          deployment_stub(0)
        )

        client.expects(:delete_deployment)
        resource.delete
      end

      it "does not fail on unset replicas" do
        client = resource.send(:client)
        client.expects(:update_deployment)
        client.expects(:get_deployment).raises(Kubeclient::ResourceNotFoundError.new(404, 'Not Found', {}))
        client.expects(:get_deployment).times(2).returns(deployment_stub(nil))
        client.expects(:delete_deployment)
        resource.delete
      end
    end

    describe "#revert" do
      it "reverts to previous version" do
        basic = {kind: 'Deployment', apiVersion: api_version, metadata: {name: 'some-project', namespace: 'pod1'}}
        previous = basic.deep_merge(metadata: {uid: 'UID'}).freeze

        with = ->(request) { request.body.must_equal basic.to_json }
        assert_request(:get, url, to_return: {body: "{}"}) do
          assert_request(:put, url, with: with, to_return: {body: "{}"}) do
            resource.revert(previous)
          end
        end
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
    let(:api_version) { 'apps/v1beta1' }

    describe "#client" do
      it "uses the apps client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.client('apps/v1beta1')
      end
    end

    describe "#deploy" do
      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "updates when existing and using RollingUpdate" do
        template[:spec][:updateStrategy] = "RollingUpdate"
        assert_request(:get, url, to_return: {body: "{}"}) do
          assert_request(:put, url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "updates when existing and using RollingUpdate" do
        template[:spec][:updateStrategy] = {type: "RollingUpdate"}
        assert_request(:get, url, to_return: {body: "{}"}) do
          assert_request(:put, url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "patches and deletes pods when using OnDelete (default)" do
        set = {
          spec: {
            replicas: 2,
            selector: {matchLabels: {project: "foo", release: "bar"}},
            template: {spec: {containers: []}}
          }
        }
        assert_request(:get, url, to_return: {body: set.to_json}) do
          assert_request(
            :patch,
            url,
            with: {headers: {"Content-Type" => "application/json-patch+json"}},
            to_return: {body: "{}"}
          ) do
            assert_pod_deletion do
              resource.expects(:sleep)
              resource.expects(:pods).times(3).returns(
                [{metadata: {creationTimestamp: '1', name: 'pod1', namespace: 'name1'}}], # old
                [{metadata: {creationTimestamp: '1'}}], # first check
                [{metadata: {creationTimestamp: '2'}}] # second check
              )
              resource.deploy
            end
          end
        end
      end

      it "does not fail when scaling down and previous generation pods have been removed already" do
        set = {
          spec: {
            replicas: 2,
            selector: {matchLabels: {project: "foo", release: "bar"}},
            template: {spec: {containers: []}}
          }
        }
        assert_request(:get, url, to_return: {body: set.to_json}) do
          assert_request(
            :patch,
            url,
            with: {headers: {"Content-Type" => "application/json-patch+json"}},
            to_return: {body: "{}"}
          ) do
            assert_request(:delete, "#{origin}/api/v1/namespaces/name1/pods/pod1", to_return: {status: 404}) do
              resource.expects(:pods).times(2).returns(
                [{metadata: {creationTimestamp: '1', name: 'pod1', namespace: 'name1'}}],
                [{metadata: {creationTimestamp: '2'}}]
              )
              resource.deploy
            end
          end
        end
      end

      it "deletes when user requested deletion" do
        delete_resource!
        resource.expects(:pods).returns([])
        assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
          assert_request(:delete, url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end
    end

    describe "#delete" do
      around { |t| assert_request(:delete, url, to_return: {body: "{}"}, &t) }

      it "deletes set and pods" do
        assert_request(:get, url, to_return: [{body: template.to_json}, {status: 404}]) do
          assert_pods_lookup do
            assert_pod_deletion do
              resource.delete
            end
          end
        end
      end
    end

    describe "#patch_replace?" do
      before { resource.stubs(:exist?).returns(true) }

      it "is a replace when replacing existing" do
        assert resource.patch_replace?
      end

      it "is not a replace when deleting" do
        delete_resource!
        refute resource.patch_replace?
      end

      it "is not a replace when creating" do
        resource.stubs(:exist?).returns(false)
        refute resource.patch_replace?
      end
    end
  end

  describe Kubernetes::Resource::Job do
    let(:kind) { 'Job' }
    let(:api_version) { 'batch/v1' }

    describe "#client" do
      it "uses the extension client because it is in beta" do
        resource.send(:client).must_equal deploy_group.kubernetes_cluster.client('batch/v1')
      end
    end

    describe "#deploy" do
      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "replaces existing" do
        job = {spec: {template: {metadata: {labels: {release_id: 123, deploy_group_id: 234}}}}}
        assert_request(:get, url, to_return: [{body: job.to_json}, {status: 404}]) do
          assert_request(:delete, url, to_return: {body: '{}'}) do
            assert_pods_lookup do
              assert_pod_deletion do
                assert_request(:post, base_url, to_return: {body: "{}"}) do
                  resource.deploy
                end
              end
            end
          end
        end
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

  describe Kubernetes::Resource::CronJob do
    let(:kind) { 'CronJob' }
    let(:api_version) { 'batch/v1' }

    describe "#desired_pod_count" do
      it "is 0 since we do not know when it will run" do
        resource.desired_pod_count.must_equal 0
      end
    end
  end

  describe Kubernetes::Resource::Service do
    let(:api_version) { 'v1' }
    let(:kind) { 'Service' }

    describe "#deploy" do
      let(:old) { {metadata: {resourceVersion: "A", foo: "B"}, spec: {clusterIP: "C"}} }
      let(:expected_body) { template.deep_merge(metadata: {resourceVersion: "A"}, spec: {clusterIP: "C"}) }

      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "replaces existing while keeping fields that kubernetes demands" do
        assert_request(:get, url, to_return: {body: old.to_json}) do
          assert_request(:put, url, with: {body: expected_body.to_json}, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "keeps whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.foo" do
          assert_request(:get, url, to_return: {body: old.to_json}) do
            with = {body: expected_body.deep_merge(metadata: {foo: "B"}).to_json}
            assert_request(:put, url, with: with, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "ignores unknown whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.nope" do
          assert_request(:get, url, to_return: {body: old.to_json}) do
            assert_request(:put, url, with: {body: expected_body.to_json}, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "allows adding whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.nope" do
          template[:metadata][:nope] = "X"
          assert_request(:get, url, to_return: {body: old.to_json}) do
            expected_body[:metadata][:nope] = "X"
            expected_body[:metadata][:resourceVersion] = expected_body[:metadata].delete(:resourceVersion) # keep order
            assert_request(:put, url, with: {body: expected_body.to_json}, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "keeps whitelisted fields via annotation" do
        template[:metadata][:annotations] = {"samson/persistent_fields": "metadata.foo"}
        assert_request(:get, url, to_return: {body: old.to_json}) do
          with = {body: expected_body.deep_merge(metadata: {foo: "B"}).to_json}
          assert_request(:put, url, with: with, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "multiple keeps whitelisted fields via annotation" do
        template[:metadata][:annotations] = {"samson/persistent_fields": "barfoo, metadata.foo"}
        assert_request(:get, url, to_return: {body: old.to_json}) do
          with = {body: expected_body.deep_merge(metadata: {foo: "B"}).to_json}
          assert_request(:put, url, with: with, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end
    end
  end

  describe Kubernetes::Resource::Pod do
    let(:kind) { 'Pod' }
    let(:api_version) { 'v1' }

    describe "#deploy" do
      let(:url) { "#{origin}/api/v1/namespaces/pod1/pods/some-project" }

      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "replaces when existing" do
        assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
          assert_request(:delete, url, to_return: {body: "{}"}) do
            assert_request(:post, base_url, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "waits for deletion to finish before replacing to avoid duplication errors" do
        resource.expects(:sleep).times(2)

        assert_request(:get, url, to_return: [{body: "{}"}, {body: "{}"}, {body: "{}"}, {status: 404, body: "{}"}]) do
          assert_request(:delete, url, to_return: {body: '{}'}) do
            assert_request(:post, base_url, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "deletes the pod when requested for deletion" do
        delete_resource!
        assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
          assert_request(:delete, url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "doesn't delete the pod if it's already deleted" do
        delete_resource!
        assert_request(:get, url, to_return: {status: 404}) do
          resource.deploy
        end
      end
    end
  end

  describe Kubernetes::Resource::APIService do
    let(:kind) { "APIService" }
    let(:api_version) { "apiregistration.k8s.io/v1beta1" }

    it "copies resourceVersion when updating to satisfy kubernetes validations" do
      assert_create_and_delete_requests do
        resource.deploy
      end
    end
  end

  describe Kubernetes::Resource::Namespace do
    let(:kind) { "Namespace" }
    let(:api_version) { "v1" }

    it "deploys" do
      assert_request(:get, url, to_return: {status: 404}) do
        assert_request(:post, base_url, to_return: {body: "{}"}) do
          resource.deploy
        end
      end
    end

    it "refuses to delete" do
      resource.delete
    end
  end

  describe Kubernetes::Resource::PodDisruptionBudget do
    let(:kind) { 'PodDisruptionBudget' }
    let(:api_version) { 'policy/v1beta1' }

    describe "#deploy" do
      it "updates" do
        assert_create_and_delete_requests do
          resource.deploy
        end
      end

      it "deletes" do
        template[:delete] = true
        assert_request(:get, url, to_return: [{body: '{}'}, {status: 404}]) do
          assert_request(:delete, url, to_return: {body: '{}'}) do
            resource.deploy
          end
        end
      end
    end

    describe "#revert" do
      it "deletes and then creates without resourceVersion because that is not allowed" do
        with = ->(request) { request.body.wont_include "resourceVersion"; true }
        assert_create_and_delete_requests(with: with) do
          resource.revert(template.deep_merge(metadata: {resourceVersion: '123'}))
        end
      end
    end
  end

  describe Kubernetes::Resource::VersionedUpdate do
    let(:kind) { 'CustomResourceDefinition' }
    let(:api_version) { 'apiextensions.k8s.io/v1beta1' }

    it "updates when resourceVersion so it does not fail" do
      assert_request(:get, url, to_return: {body: {metadata: {resourceVersion: "123"}}.to_json}) do
        args = ->(x) { x.body.must_include '"resourceVersion":"123"'; true }
        assert_request(:put, url, to_return: {body: "{}"}, with: args) do
          resource.deploy
        end
      end
    end
  end
end
