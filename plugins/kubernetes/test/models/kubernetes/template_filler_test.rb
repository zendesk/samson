# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::TemplateFiller do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }
  let(:raw_template) do
    raw_template = YAML.load(read_kubernetes_sample_file('kubernetes_deployment.yml')).deep_symbolize_keys
    raw_template[:metadata][:namespace] = "pod1"
    raw_template
  end
  let(:template) { Kubernetes::TemplateFiller.new(doc, raw_template) }

  before do
    doc.send(:resource_template=, YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml')))
    doc.kubernetes_release.deploy_id = 123
    stub_request(:get, "http://foobar.server/api/v1/namespaces/pod1/secrets").to_return(body: "{}")
    Samson::Secrets::VaultClient.any_instance.stubs(:client).
      returns(stub(options: {address: 'https://test.hvault.server', ssl_verify: false}))
  end

  describe "#to_hash" do
    it "works" do
      result = template.to_hash
      result.size.must_equal 4

      spec = result.fetch(:spec)
      spec.fetch(:uniqueLabelKey).must_equal "rc_unique_identifier"
      spec.fetch(:replicas).must_equal doc.replica_target
      spec.fetch(:template).fetch(:metadata).fetch(:labels).symbolize_keys.must_equal(
        revision: "abababababa",
        tag: "master",
        release_id: doc.kubernetes_release_id.to_s,
        project: "some-project",
        project_id: doc.kubernetes_release.project_id.to_s,
        role_id: doc.kubernetes_role_id.to_s,
        role: "some-role",
        deploy_group: 'pod1',
        deploy_group_id: doc.deploy_group_id.to_s,
        deploy_id: "123"
      )

      metadata = result.fetch(:metadata)
      metadata.fetch(:namespace).must_equal 'pod1'
      metadata.fetch(:labels).symbolize_keys.must_equal(
        project: 'some-project',
        role: 'some-role'
      )
    end

    it "escapes things that would not be allowed in labels or environment values" do
      doc.deploy_group.update_column(:env_value, 'foo:bar')
      doc.kubernetes_release.update_column(:git_ref, 'user/feature')

      result = template.to_hash
      result.fetch(:spec).fetch(:template).fetch(:metadata).fetch(:labels).slice(:deploy_group, :role, :tag).must_equal(
        tag: "user-feature",
        deploy_group: 'foo-bar',
        role: 'some-role'
      )
    end

    it "overrides the name" do
      template.to_hash[:metadata][:name].must_equal 'test-app-server'
    end

    it "sets imagePullSecrets" do
      reply = {
        items: [
          {type: "kubernetes.io/dockercfg", metadata: {name: 'a'}},
          {type: "kubernetes.io/nope", metadata: {name: 'b'}},
          {type: "kubernetes.io/dockercfg", metadata: {name: 'c'}}
        ]
      }
      stub_request(:get, "http://foobar.server/api/v1/namespaces/pod1/secrets").to_return(body: reply.to_json)
      template.to_hash[:spec][:template][:spec][:imagePullSecrets].must_equal(
        [{name: 'a'}, {name: 'c'}]
      )
    end

    it "sets revisionHistoryLimit" do
      template.to_hash[:spec][:revisionHistoryLimit].must_equal 1
    end

    describe "containers" do
      let(:result) { template.to_hash }
      let(:container) { result.fetch(:spec).fetch(:template).fetch(:spec).fetch(:containers).first }

      it "overrides image" do
        container.fetch(:image).must_equal(
          'docker-registry.example.com/test@sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c'
        )
      end

      it "does not override image when no build was made" do
        doc.kubernetes_release.build = nil
        container.fetch(:image).must_equal(
          "docker-registry.zende.sk/truth_service:latest"
        )
      end

      it "copies resource values" do
        container.fetch(:resources).must_equal(
          limits: {
            memory: "100Mi",
            cpu: 1.0
          }
        )
      end

      it "fills then environment with string values" do
        env = container.fetch(:env)
        env.map { |x| x.fetch(:name) }.sort.must_equal(
          %w[
            REVISION
            TAG
            PROJECT
            ROLE
            DEPLOY_ID
            DEPLOY_GROUP
            POD_NAME
            POD_NAMESPACE
            POD_IP
            KUBERNETES_CLUSTER_NAME
          ].sort
        )
        env.map { |x| x[:value] }.map(&:class).map(&:name).sort.uniq.must_equal(["NilClass", "String"])
      end

      # https://github.com/zendesk/samson/issues/966
      it "allows multiple containers, even though they will not be properly replaced" do
        raw_template[:spec][:template][:metadata][:containers] = [{}, {}]
        template.to_hash
      end

      it "merges existing env settings" do
        template.send(:template)[:spec][:template][:spec][:containers][0][:env] = [{name: 'Foo', value: 'Bar'}]
        keys = container.fetch(:env).map { |x| x.fetch(:name) }
        keys.must_include 'Foo'
        keys.size.must_be :>, 5
      end

      it "adds env from deploy_group_env hook" do
        Samson::Hooks.with_callback(:deploy_group_env, ->(p, dg) { {FromEnv: "#{p.name}-#{dg.name}"} }) do
          container.fetch(:env).must_include(name: 'FromEnv', value: 'Foo-Pod1')
        end
      end

      it "overrides container env with deploy_group_env so samson can modify env variables" do
        raw_template[:spec][:template][:spec][:containers].first[:env] = [{name: 'FromEnv', value: 'THIS-IS-BAD'}]
        # plugins can return string or symbol keys, we should be prepared for both
        callback = ->(*) { {'FromEnv' => "THIS-IS-MEH", FromEnv: "THIS-IS-GOOD"} }
        Samson::Hooks.with_callback(:deploy_group_env, callback) do
          container.fetch(:env).select { |e| e[:name] == 'FromEnv' }.must_equal(
            [{name: 'FromEnv', value: 'THIS-IS-GOOD'}]
          )
        end
      end
    end

    describe "secret-puler-containers" do
      let(:secret_key) { "global/global/global/bar" }
      let(:template_env) { template.to_hash[:spec][:template][:spec][:containers].first[:env] }
      let(:init_container_key) { 'pod.beta.kubernetes.io/init-containers' }
      let(:init_containers) do
        JSON.parse(template.to_hash[:spec][:template][:metadata][:annotations][init_container_key])
      end

      around do |test|
        klass = Kubernetes::TemplateFiller
        silence_warnings { klass.const_set(:SECRET_PULLER_IMAGE, "docker-registry.example.com/foo:bar") }
        test.call
        silence_warnings { klass.const_set(:SECRET_PULLER_IMAGE, nil) }
      end

      before do
        raw_template[:spec][:template][:metadata][:annotations] = {"secret/FOO": "bar"}
        create_secret(secret_key)
      end

      it "adds secret puller container" do
        init_containers.first['name'].must_equal('secret-puller')
        init_containers.first['env'].must_equal(
          [
            {"name" => "VAULT_ADDR", "value" => "https://test.hvault.server"},
            {"name" => "VAULT_SSL_VERIFY", "value" => "false"}
          ]
        )

        # secrets got resolved?
        template.to_hash[:spec][:template][:metadata][:annotations].
          except(init_container_key).must_equal(
            "secret/FOO" => "global/global/global/bar"
          )
      end

      it "keeps existing init containers" do
        annotations = raw_template[:spec][:template][:metadata][:annotations]
        annotations[init_container_key] = [{a: 1}].to_json
        init_containers[1].must_equal('a' => 1)
      end

      it "fails when vault is not configured" do
        with_env('SECRET_STORAGE_BACKEND': "SecretStorage::HashicorpVault") do
          Samson::Secrets::VaultClient.client.expects(:client).raises("Could not find Vault config for pod1")
          e = assert_raises { template.to_hash }
          e.message.must_equal "Could not find Vault config for pod1"
        end
      end

      it "adds the vault server address to the cotainers env" do
        with_env(SECRET_STORAGE_BACKEND: "SecretStorage::HashicorpVault") do
          assert template_env.any? { |env| env.any? { |_k, v| v == "VAULT_ADDR" } }
        end
      end

      it "does not add the vault server address to the cotainers env" do
        with_env(SECRET_STORAGE_BACKEND: "foobar") do
          refute template_env.any? { |env| env.any? { |_k, v| v == "VAULT_ADDR" } }
        end
      end

      it "adds to existing volume definitions in the puller" do
        raw_template[:spec][:template][:spec][:volumes] = [{}, {}]
        template.to_hash[:spec][:template][:spec][:volumes].count.must_equal 5
      end

      it "adds to existing volume definitions in the primary container" do
        raw_template[:spec][:template][:spec][:containers] = [
          {name: 'foo', volumeMounts: [{name: 'bar'}]}
        ]
        template.to_hash[:spec][:template][:spec][:containers].first[:volumeMounts].count.must_equal 2
      end

      it "adds to existing volume definitions in the primary container when volumeMounts is empty" do
        raw_template[:spec][:template][:spec][:containers] = [
          {name: 'foo', volumeMounts: nil}
        ]
        template.to_hash[:spec][:template][:spec][:containers].first[:volumeMounts].count.must_equal 1
      end

      it "creates no puller when there are no secrets" do
        raw_template[:spec][:template][:metadata][:annotations].replace('public/foobar': 'xyz')
        template.to_hash[:spec][:template][:spec][:containers].map { |c| c[:name] }.must_equal(['some-project'])
      end

      it "fails when it cannot find secrets needed by the puller" do
        raw_template[:spec][:template][:metadata][:annotations].replace('secret/FOO': 'bar', 'secret/BAR': 'baz')
        SecretStorage.delete(secret_key)
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_include "bar (tried: production/foo/pod1/bar"
        e.message.must_include "baz (tried: production/foo/pod1/baz" # shows all at once for easier debugging
      end
    end

    describe "daemon_set" do
      before do
        raw_template[:kind] = 'DaemonSet'
        raw_template[:spec].delete(:replicas)
      end

      it "does not add replicas since they are not supported" do
        result = template.to_hash
        refute result[:spec].key?(:replicas)
      end
    end

    describe "pod" do
      before do
        original_metadata = raw_template.fetch(:metadata)
        raw_template.replace(raw_template.dig(:spec, :template))
        raw_template[:metadata].merge!(original_metadata)
        raw_template[:kind] = "Pod"
        raw_template[:spec].delete :replicas
      end

      it "fills out everything" do
        result = template.to_hash
        assert result[:metadata][:labels][:project]
        result[:spec][:containers][0][:image].must_include 'sha256'
        result[:spec][:containers][0][:env].map { |e| e[:name] }.must_include 'POD_NAMESPACE'
        refute result[:spec][:revisionHistoryLimit]
        refute result[:spec][:uniqueLabelKey]
      end

      it "does not set replicas since they are not supported" do
        result = template.to_hash
        refute result[:spec].key?(:replicas)
      end
    end
  end

  describe "#verify_env" do
    it "passes when nothing is required" do
      template.expects(:set_env).never # does not call expensive stuff if nothing is required
      template.verify_env
    end

    describe "when something is required" do
      before { raw_template[:spec][:template][:metadata][:annotations] = {"samson/required_env": 'FOO'} }

      it "fails when value is missing" do
        assert_raises Samson::Hooks::UserError do
          template.verify_env
        end
      end

      it "passes when missing value is filled out" do
        EnvironmentVariable.create!(parent: projects(:test), name: 'FOO', value: 'BAR')
        template.verify_env
      end
    end
  end
end
