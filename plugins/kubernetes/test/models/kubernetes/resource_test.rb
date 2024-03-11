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
      template_modified = content.scan(/@template(?: =|\.dig_set|\.delete).*/)
      template_modified.size.must_equal restore_usages + 2, template_modified # we use = twice inside of restore
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
      let(:api_version) { 'apps/v1' }
      let(:url) { "#{origin}/apis/apps/v1/namespaces/pod1/deployments/some-project" }

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

      it "keeps replicas when autoscaled, to not revert autoscaler changes" do
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
            e.message.must_include "Kubernetes error Deployment some-project pod1 Pod1: Foo"
          end
        end
      end

      it "can keep persistent fields" do
        with = ->(r) do
          body = JSON.parse(r.body)
          body.fetch("foo").must_equal "bar"
          refute body["baz"]
          true
        end
        template[:metadata][:annotations] = {"samson/persistent_fields": "foo"}
        assert_request(:get, url, to_return: {body: {foo: "bar", baz: "bar"}.to_json}, times: 1) do
          assert_request(:put, url, with: with, to_return: {body: "{}"}) do
            resource.deploy
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

      describe "server-side apply" do
        before { template[:metadata][:annotations] = {"samson/server_side_apply": "true"} }

        it "updates" do
          assert_request(:get, url, to_return: {body: "{}"}) do
            args = ->(x) { x.body.must_include '"replicas":2'; true }
            assert_request(:patch, "#{url}?fieldManager=samson&force=true", to_return: {body: "{}"}, with: args) do
              resource.deploy
            end
          end
        end

        it "creates when missing" do
          assert_request(:get, url, to_return: {status: 404}) do
            args = ->(x) { x.body.must_include '"replicas":2'; true }
            assert_request(:patch, "#{url}?fieldManager=samson&force=true", to_return: {body: "{}"}, with: args) do
              resource.deploy
            end
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

      describe "creating crds" do
        let(:kind) { "ConstraintTemplate" }
        let(:api_version) { 'constraints.gatekeeper.sh/v1beta1' }

        it "waits for CRDs to be created to not fail next resource" do
          stub_request(:get, "http://foobar.server/apis/constraints.gatekeeper.sh/v1beta1").
            to_return(body: {
              "resources" => [
                {"name" => "constrainttemplate", "namespaced" => false, "kind" => "ConstraintTemplate"}
              ]
            }.to_json)

          url = "http://foobar.server/apis/constraints.gatekeeper.sh/v1beta1/namespaces/pod1/constrainttemplate"
          assert_request(:post, url, to_return: {body: {}.to_json}) do
            resource.expects(:sleep).times(1)
            resource.send(:create)
          end
        end
      end
    end

    describe "#exist?" do
      let(:retries) { SamsonKubernetes::API_RETRIES }

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
        assert_request(:get, url, to_return: {status: 500}, times: retries + 1) do
          assert_raises(Kubeclient::HttpError) { resource.exist? }
        end
      end

      it "raises SSL exception is raised" do
        assert_request(:get, url, to_raise: OpenSSL::SSL::SSLError, times: retries + 1) do
          assert_raises(OpenSSL::SSL::SSLError) { resource.exist? }
        end
      end
    end

    describe "#delete" do
      it "deletes" do
        assert_request(:delete, url, to_return: {body: "{}"}) do
          assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
            resource.delete
          end
        end
      end

      it "does nothing when deleted" do
        assert_request(:get, url, to_return: [{status: 404}]) do
          resource.delete
        end
      end

      it "fetches after deleting" do
        assert_request(:delete, url, to_return: {body: "{}"}) do
          assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
            resource.delete
            refute resource.exist?
          end
        end
      end

      it "fails when deletion fails" do
        assert_request(:delete, url, to_return: {body: "{}"}) do
          tries = Kubernetes::Resource::DELETE_BACKOFF.size
          assert_request(:get, url, to_return: {body: "{}"}, times: tries + 1) do
            resource.expects(:sleep).times(tries)

            e = assert_raises(RuntimeError) { resource.delete }
            e.message.must_equal(
              "Unable to delete resource (try scaling to 0 first without deletion) (ConfigMap some-project pod1 Pod1)"
            )
          end
        end
      end

      it "uses background deletion to avoid bugs with foreground deletion when we do not need to clean up pods" do
        assert_request(:delete, url, with: ->(r) { r.body.must_include "Background" }, to_return: {body: "{}"}) do
          assert_request(:get, url, to_return: [{body: {spec: {replicas: 0}}.to_json}, {status: 404}]) do
            resource.delete
          end
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

      it "is 0 when resource is a PodTemplate" do
        template[:kind] = "PodTemplate"
        resource.desired_pod_count.must_equal 0
      end
    end

    describe "#request" do
      it "returns response" do
        stub_request(:get, "http://foobar.server/api/v1/configmaps/foo").to_return body: '{"foo": "bar"}'
        resource.send(:request, :get, :foo).must_equal foo: "bar"
      end

      it "shows nice error message when user uses the wrong apiVersion" do
        template[:apiVersion] = 'apps/v1'
        e = assert_raises(Samson::Hooks::UserError) { resource.send(:request, :get, :foo) }
        e.message.must_equal(
          "apiVersion apps/v1 does not support ConfigMap. Check kubernetes docs for correct apiVersion"
        )
      end

      it "shows location when api fails" do
        stub_request(:get, "http://foobar.server/api/v1/configmaps/foo").to_return status: 429
        e = assert_raises(Kubeclient::HttpError) { resource.send(:request, :get, :foo) }
        e.message.must_equal "Kubernetes error ConfigMap some-project pod1 Pod1: 429 Too Many Requests"
      end

      it "does not crash on frozen messages" do
        resource.send(:client).expects(:get_config_map).
          raises(Kubeclient::ResourceNotFoundError.new(404, 'FROZEN', {}))
        e = assert_raises(Kubeclient::ResourceNotFoundError) { resource.send(:request, :get, :foo) }
        e.message.must_equal "FROZEN"
      end

      it "retries on conflict with updated version" do
        resource.send(:client).expects(:update_config_map).
          with(metadata: {resourceVersion: "old"}).
          raises(Kubeclient::HttpError.new(409, 'Conflict', {}))
        resource.send(:client).expects(:get_config_map).
          returns(metadata: {resourceVersion: "new"})
        resource.send(:client).expects(:update_config_map).
          with(metadata: {resourceVersion: "new"}).
          returns({})

        resource.send(:request, :update, metadata: {resourceVersion: "old"})
      end
    end
  end

  describe Kubernetes::Resource::DaemonSet do
    let(:kind) { 'DaemonSet' }
    let(:api_version) { 'apps/v1' }

    describe "#desired_pod_count" do
      before { template[:spec] = {replicas: 2} }

      it "reads the value from the server since it is complicated" do
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
        assert_request(:get, url, to_return: {body: {status: {desiredNumberScheduled: 0}}.to_json}, times: 6) do
          resource.expects(:sleep).times(5)
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
      let(:api_version) { 'apps/v1' }
      let(:base_url) { "#{origin}/apis/apps/v1/namespaces/bar/daemonsets" }

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

  describe Kubernetes::Resource::StatefulSet do
    def deployment_stub(replica_count)
      {
        spec: {},
        status: {replicas: replica_count}
      }.to_json
    end

    let(:kind) { 'StatefulSet' }
    let(:api_version) { 'apps/v1beta1' }

    describe "#deploy" do
      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "refuses OnDelete since that would fail and leave pods running " do
        template[:spec][:updateStrategy] = {type: "OnDelete"}
        assert_raises Samson::Hooks::UserError do
          resource.deploy
        end
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
      let(:old) { {metadata: {foo: "B"}, spec: {clusterIP: "C"}} }
      let(:old_with_ports) do
        {
          metadata: {foo: "B"},
          spec: {clusterIP: "C", ports: [{name: "http", port: 80, nodePort: 30080}]}
        }
      end
      let(:expected_body) { template.deep_merge(spec: {clusterIP: "C"}) }
      let(:expected_body_version) { expected_body.deep_merge(metadata: {resourceVersion: nil}) }

      it "creates when missing" do
        assert_request(:get, url, to_return: {status: 404}) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "updates when existing" do
        assert_request(:get, url, to_return: {body: "{}"}) do
          assert_request(:put, url, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "replaces existing while keeping fields that kubernetes demands" do
        assert_request(:get, url, to_return: {body: old.to_json}) do
          assert_request(:put, url, with: {body: expected_body_version.to_json}, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "keeps whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.foo" do
          assert_request(:get, url, to_return: {body: old.to_json}) do
            with = {body: expected_body.deep_merge(metadata: {foo: "B", resourceVersion: nil}).to_json}
            assert_request(:put, url, with: with, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "keeps nodePorts" do
        service_template = {
          kind: kind,
          apiVersion: api_version,
          metadata: {name: 'some-project', namespace: 'pod1'},
          spec: {
            clusterIP: "C",
            ports: [{name: "http", port: 80, nodePort: 30080}]
          }
        }
        service_resource = Kubernetes::Resource.build(
          service_template, deploy_group, autoscaled: false, delete_resource: false
        )
        expected_body = service_template.deep_merge(
          spec: {clusterIP: "C", ports: [{name: "http", port: 80, nodePort: 30080}]}
        )

        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.foo" do
          assert_request(:get, url, to_return: {body: old_with_ports.to_json}) do
            expected = expected_body.deep_merge(metadata: {foo: "B", resourceVersion: nil})
            assert_request(:put, url, with: request_with_json(expected), to_return: {body: "{}"}) do
              service_resource.deploy
            end
          end
        end
      end

      it "ignores unknown whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.nope" do
          assert_request(:get, url, to_return: {body: old.to_json}) do
            assert_request(:put, url, with: {body: expected_body_version.to_json}, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "allows adding whitelisted fields" do
        with_env KUBERNETES_SERVICE_PERSISTENT_FIELDS: "metadata.nope" do
          template[:metadata][:nope] = "X"
          assert_request(:get, url, to_return: {body: old.to_json}) do
            expected = expected_body.deep_merge(metadata: {nope: "X", resourceVersion: nil})
            assert_request(:put, url, with: {body: expected.to_json}, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      it "keeps whitelisted fields via annotation" do
        template[:metadata][:annotations] = {"samson/persistent_fields": "metadata.foo"}
        assert_request(:get, url, to_return: {body: old.to_json}) do
          expected = expected_body.deep_merge(metadata: {foo: "B", resourceVersion: nil})
          assert_request(:put, url, with: {body: expected.to_json}, to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      it "multiple keeps whitelisted fields via annotation" do
        template[:metadata][:annotations] = {"samson/persistent_fields": "barfoo, metadata.foo"}
        assert_request(:get, url, to_return: {body: old.to_json}) do
          expected = expected_body.deep_merge(metadata: {foo: "B", resourceVersion: nil})
          assert_request(:put, url, with: request_with_json(expected), to_return: {body: "{}"}) do
            resource.deploy
          end
        end
      end

      # TODO: does not work for deployments because there we update replicas first
      it "recreates when requested" do
        template[:metadata][:annotations] = {"samson/recreate": "true"}
        assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
          assert_request(:delete, url, to_return: {body: "{}"}) do
            assert_request(:post, base_url, to_return: {body: "{}"}) do
              resource.deploy
            end
          end
        end
      end

      describe "forced update" do
        def assert_recreate(error)
          assert_request(:get, url, to_return: [{body: "{}"}, {status: 404}]) do
            assert_request(:put, url, to_return: {body: {message: error}.to_json, status: 422}) do
              assert_request(:delete, url, to_return: {body: '{}'}) do
                assert_request(:post, base_url, to_return: {body: '{}'}) do
                  resource.deploy
                end
              end
            end
          end
        end

        let(:error) { +"Foo is invalid: cannot change spec.bar" }

        before do
          template[:metadata][:annotations] = {"samson/force_update": "true"}
        end

        it "re-creates when updating is not possible" do
          assert_recreate(error)
        end

        it "re-creates when fields are forbidden" do
          assert_recreate(
            "StatefulSet.apps \"foo\" is invalid: spec: Forbidden: " \
            "updates to statefulset spec for fields other than 'bar' are forbidden"
          )
        end

        it "tells users how to enable re-create" do
          template[:metadata][:annotations].clear

          assert_request(:get, url, to_return: [{body: "{}"}]) do
            assert_request(:put, url, to_return: {body: {message: error}.to_json, status: 422}) do
              e = assert_raises(Samson::Hooks::UserError) { resource.deploy }
              e.message.must_include "samson/force_update"
            end
          end
        end

        it "does not re-creates when spec is invalid" do
          error = "Foo is invalid: spec.bar is not allowed"
          assert_request(:get, url, to_return: {body: "{}"}) do
            assert_request(:put, url, to_return: {body: {message: error}.to_json, status: 422}) do
              assert_raises(Samson::Hooks::UserError) { resource.deploy }
            end
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
    let(:api_version) { 'policy/v1' }

    describe "#deploy" do
      it "updates" do
        assert_request(:get, url, to_return: [{body: '{}'}]) do
          assert_request(:put, url, to_return: {body: '{}'}) do
            resource.deploy
          end
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
  end

  describe Kubernetes::Resource::ServiceAccount do
    let(:kind) { 'ServiceAccount' }
    let(:api_version) { 'v1' }

    describe "#deploy" do
      it "updates" do
        with = ->(r) { r.body.must_include '"a":1' }
        assert_request(:get, url, to_return: [{body: {secrets: [{a: 1}]}.to_json}]) do
          assert_request(:put, url, to_return: {body: '{}'}, with: with) do
            resource.deploy
          end
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

  describe Kubernetes::Resource::PatchReplace do
    let(:kind) { 'PersistentVolumeClaim' }
    let(:api_version) { 'v1' }
    let(:template) do
      {
        kind: kind,
        apiVersion: api_version,
        metadata: {name: 'some-project', namespace: 'pod1'},
        spec: {
          resources: {
            requests: {}
          }
        }
      }
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

    describe "#deploy" do
      it "doesn't patch when creating" do
        assert_request(:get, url, to_return: [{status: 404}, {body: "{}"}]) do
          assert_request(:post, base_url, to_return: {body: "{}"}) do
            resource.deploy
          end

          # not auto-cached
          assert resource.exist?
          assert resource.exist?
        end
      end

      it "patches when updating" do
        resource.expects(:patch_replace)
        assert_request(:get, url, to_return: [{body: '{"spec":{"resources:": {"requests":{}}}}'}]) do
          resource.deploy
        end
      end
    end

    describe "#patch_paths" do
      it "returns list of supported paths" do
        assert resource.send(:patch_paths).any?
      end
    end

    describe "#patch_replace" do
      before { resource.stubs(:exist?).returns(true) }

      it "sends patch request" do
        assert_request(:get, url, to_return: {body: '{"spec":{"resources": {"requests":{}}}}'}) do
          assert_request(:patch, url, to_return: {body: "{}"}) do
            assert resource.send(:patch_replace)
          end
        end
      end
    end
  end
end
