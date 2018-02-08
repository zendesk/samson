# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::TemplateFiller do
  def add_init_container(container)
    annotations = (raw_template[:spec][:template][:metadata][:annotations] ||= {})
    annotations[init_container_key] = [container].to_json
  end

  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }
  let(:raw_template) do
    raw_template = YAML.safe_load(read_kubernetes_sample_file('kubernetes_deployment.yml')).deep_symbolize_keys
    raw_template[:metadata][:namespace] = "pod1"
    raw_template
  end
  let(:template) { Kubernetes::TemplateFiller.new(doc, raw_template, index: 0) }
  let(:init_container_key) { :'pod.beta.kubernetes.io/init-containers' }
  let(:init_containers) do
    JSON.parse(template.to_hash[:spec][:template][:metadata][:annotations][init_container_key])
  end

  before do
    doc.send(:resource_template=, YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml')))
    doc.kubernetes_release.builds = [builds(:docker_build)]

    stub_request(:get, %r{http://foobar.server/api/v1/namespaces/\S+/secrets}).to_return(body: "{}")
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
        revision: "1a6f551a2ffa6d88e15eef5461384da0bfb1c194",
        tag: "master",
        release_id: doc.kubernetes_release_id.to_s,
        project: "some-project",
        project_id: doc.kubernetes_release.project_id.to_s,
        role_id: doc.kubernetes_role_id.to_s,
        role: "some-role",
        deploy_group: 'pod1',
        deploy_group_id: doc.deploy_group_id.to_s,
        deploy_id: doc.kubernetes_release.deploy_id.to_s
      )

      metadata = result.fetch(:metadata)
      metadata.fetch(:namespace).must_equal 'pod1'
      metadata.fetch(:labels).symbolize_keys.must_equal(
        project: 'some-project',
        role: 'some-role'
      )

      # only symbol keys used because that is what we receive from a real input
      result.deep_symbolize_keys.must_equal result
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
          {type: "kubernetes.io/dockerconfigjson", metadata: {name: 'c'}},
          {type: "kubernetes.io/dockerNotValidConfigThing", metadata: {name: 'd'}}
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

    it "keeps default namespace because it is a unique system namespace" do
      raw_template[:metadata][:namespace] = "default"
      raw_template[:metadata][:labels] = {"kubernetes.io/cluster-service": 'true'}
      template.to_hash[:metadata][:namespace].must_equal 'default'
    end

    it "keeps kube-system namespace because it's valid for cluster services " do
      raw_template[:metadata][:namespace] = "kube-system"
      raw_template[:metadata][:labels] = {"kubernetes.io/cluster-service": 'true'}
      template.to_hash[:metadata][:namespace].must_equal 'kube-system'
    end

    describe "unqiue deployments" do
      let(:labels) do
        hash = template.to_hash
        [
          hash.dig(:metadata, :labels, :project),
          hash.dig(:spec, :selector, :project),
          hash.dig(:spec, :selector, :matchLabels, :project),
          hash.dig(:spec, :template, :metadata, :labels, :project),
        ]
      end

      before { raw_template[:metadata][:annotations] = {"samson/override_project_label": "true"} }

      it "overrides project label in primary" do
        labels.must_equal ["foo", nil, "foo", "foo"]
      end

      it "overrides project label in pod" do
        raw_template.replace(raw_template.dig(:spec, :template).merge(raw_template.slice(:metadata)))
        raw_template[:kind] = "Pod"
        labels.must_equal ["foo", nil, nil, nil]
      end

      it "overrides project label in service" do
        raw_template[:kind] = "Service"
        labels.must_equal ["foo", "foo", "some-project", "some-project"]
      end
    end

    describe "deployer" do
      let(:result) { template.to_hash.dig_fetch(:spec, :template, :metadata, :annotations, :deployer) }

      it "sets deployer" do
        result.must_equal "deployer@example.com"
      end

      it "does not set nil deployer which breaks kubernetes api" do
        doc.kubernetes_release.user.email = nil
        result.must_equal ""
      end
    end

    describe "owner" do
      let(:result) { template.to_hash.dig_fetch(:spec, :template, :metadata, :annotations, :owner) }

      it "sets owner" do
        doc.kubernetes_release.project.owner = "foo@bar.com"
        result.must_equal "foo@bar.com"
      end

      it "does not set nil owner which breaks kubernetes api" do
        doc.kubernetes_release.project.owner = nil
        result.must_equal ""
      end
    end

    describe "configmap" do
      it "only modifies namespec" do
        raw_template[:kind] = "ConfigMap"
        raw_template[:metadata][:namespace] = 'old'
        old = raw_template.deep_dup
        old[:metadata][:namespace] = 'pod1'
        template.to_hash.must_equal old
      end
    end

    describe "service" do
      before { raw_template[:kind] = 'Service' }

      it "sets node port" do
        template.to_hash[:spec][:type].must_equal 'NodePort'
      end

      it "does not override with blank service name" do
        doc.kubernetes_role.update_column(:service_name, '') # user left field empty
        template.to_hash[:metadata][:name].must_equal 'some-project-rc'
      end

      it "fails when trying to fill for a generated service" do
        doc.kubernetes_role.update_column(:service_name, "app-server#{Kubernetes::Role::GENERATED}1211212")
        e = assert_raises Samson::Hooks::UserError do
          template.to_hash
        end
        e.message.must_include "Service name for role app-server was generated"
      end

      describe "when using multiple services" do
        before do
          doc.kubernetes_role.update_column(:service_name, 'foo')
          template.instance_variable_set(:@index, 1)
        end

        it "adds counter to service names" do
          template.to_hash[:metadata][:name].must_equal 'foo-2'
        end

        it "keeps prefixed service names when using multiple services" do
          raw_template[:metadata][:name] = 'foo-other'
          template.to_hash[:metadata][:name].must_equal 'foo-other'
        end

        it "does not keeps identical service names" do
          raw_template[:metadata][:name] = 'foo'
          template.to_hash[:metadata][:name].must_equal 'foo-2'
        end
      end

      describe "clusterIP" do
        let(:ip) { template.to_hash[:spec][:clusterIP] }

        before do
          doc.deploy_group.kubernetes_cluster.update_column(:ip_prefix, '123.34')
          raw_template[:spec][:clusterIP] = "1.2.3.4"
        end

        it "replaces ip prefix" do
          ip.must_equal '123.34.3.4'
        end

        it "replaces with trailing ." do
          doc.deploy_group.kubernetes_cluster.update_column(:ip_prefix, '123.34.')
          ip.must_equal '123.34.3.4'
        end

        it "does nothing when service has no clusterIP" do
          raw_template[:spec].delete(:clusterIP)
          ip.must_be_nil
        end

        it "does nothing when ip prefix is blank" do
          doc.deploy_group.kubernetes_cluster.update_column(:ip_prefix, '')
          ip.must_equal '1.2.3.4'
        end

        it "leaves None alone" do
          raw_template[:spec][:clusterIP] = "None"
          ip.must_equal 'None'
        end
      end
    end

    describe "statefulset" do
      before { raw_template[:kind] = "StatefulSet" }

      describe "serviceName" do
        let(:service_name) { template.to_hash[:spec][:serviceName] }

        before do
          doc.kubernetes_role.update_column(:service_name, 'changed')
          raw_template[:spec][:serviceName] = "unchanged"
        end

        it "changes the set serviceName" do
          service_name.must_equal 'changed'
        end

        it "does nothing when service_name was not set" do
          doc.kubernetes_role.update_column(:service_name, '')
          service_name.must_equal 'unchanged'
        end

        it "does nothing when serviceName was not used" do
          raw_template[:spec].delete :serviceName
          service_name.must_be_nil
        end
      end
    end

    describe "containers" do
      let(:result) { template.to_hash }
      let(:containers) { result.dig_fetch(:spec, :template, :spec, :containers) }
      let(:container) { containers.first }

      describe "image manipulation" do
        let(:build) { builds(:docker_build) }
        let(:image) { build.docker_repo_digest }

        it "overrides image" do
          container.fetch(:image).must_equal image
        end

        it "raises when build was not found" do
          doc.kubernetes_release.builds = []

          assert_raises Samson::Hooks::UserError do
            container.fetch(:image)
          end
        end

        describe "when dockerfile was selected" do
          before { raw_template[:spec][:template][:spec][:containers][0][:"samson/dockerfile"] = "Dockerfile.new" }

          it "finds special build" do
            digest = "docker-registry.example.com/new@sha256:#{"a" * 64}"
            doc.kubernetes_release.builds << builds(:v1_tag)
            doc.kubernetes_release.builds.last.update_columns(
              git_sha: doc.kubernetes_release.git_sha,
              docker_repo_digest: digest,
              dockerfile: 'Dockerfile.new'
            )
            container.fetch(:image).must_equal digest
          end

          it "complains when build was not found" do
            e = assert_raises(Samson::Hooks::UserError) { container }
            e.message.must_equal "Build for dockerfile Dockerfile.new not found, found: Dockerfile"
          end
        end

        it "allows selecting dockerfile for init containers" do
          add_init_container "samson/dockerfile": 'Dockerfile'
          init_containers[0].must_equal("samson/dockerfile" => "Dockerfile", "image" => image)
        end

        it "raises if an init container does not specify a dockerfile" do
          add_init_container a: 1, "samson/dockerfile": 'Foo'
          e = assert_raises(Samson::Hooks::UserError) { init_containers[0] }
          e.message.must_equal "Build for dockerfile Foo not found, found: Dockerfile"
        end

        describe "when project does not build images" do
          before do
            doc.kubernetes_release.project.docker_image_building_disabled = true
            build.update_column(:image_name, 'truth_service')
          end

          it "fills matching image from builds" do
            container.fetch(:image).must_equal image
          end

          it "fails when build is not found" do
            build.update_column(:image_name, 'nope')
            e = assert_raises(Samson::Hooks::UserError) { container.fetch(:image).must_equal image }
            e.message.must_include "Did not find build for image_name truth_service"
          end
        end
      end

      it "copies resource values" do
        container.fetch(:resources).must_equal(
          requests: {
            cpu: 0.5,
            memory: "50M"
          },
          limits: {
            cpu: 1.0,
            memory: "100M"
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

      describe "with multiple containers" do
        before { raw_template[:spec][:template][:spec][:containers] = [{}, {}] }

        it "allows multiple containers, even though they will not be properly replaced" do
          template.to_hash
        end

        it "fills all container envs" do
          template.to_hash
          containers[0][:env].must_equal containers[1][:env]
        end
      end
    end

    describe "secret-puler-containers" do
      let(:secret_key) { "global/global/global/bar" }
      let(:template_env) { template.to_hash[:spec][:template][:spec][:containers].first[:env] }

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
          except(init_container_key, :deployer, :owner).must_equal(
            "secret/FOO" => "global/global/global/bar"
          )
      end

      it "fails when vault is not configured" do
        with_env('SECRET_STORAGE_BACKEND': "Samson::Secrets::HashicorpVaultBackend") do
          Samson::Secrets::VaultClient.client.expects(:client).raises("Could not find Vault config for pod1")
          e = assert_raises { template.to_hash }
          e.message.must_equal "Could not find Vault config for pod1"
        end
      end

      it "adds the vault server address to the containers env when using vault" do
        with_env(SECRET_STORAGE_BACKEND: "Samson::Secrets::HashicorpVaultBackend") do
          assert template_env.any? { |env| env.any? { |_k, v| v == "VAULT_ADDR" } }
        end
      end

      it "does not add the vault server when not using vault" do
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
        Samson::Secrets::Manager.delete(secret_key)
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_include "bar\n  (tried: production/foo/pod1/bar"
        e.message.must_include "baz\n  (tried: production/foo/pod1/baz" # shows all at once for easier debugging
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

    describe "preStop" do
      it "adds preStop to avoid 502 errors when server addresses are cached for a few seconds" do
        template.to_hash.dig_fetch(:spec, :template, :spec, :containers, 0, :lifecycle).must_equal(
          preStop: {exec: {command: ["sleep", "3"]}}
        )
      end

      it "does not add preStop when it was already defined" do
        raw_template.dig_fetch(:spec, :template, :spec, :containers, 0)[:lifecycle] = {preStop: "OLD"}
        template.to_hash.dig_fetch(:spec, :template, :spec, :containers, 0, :lifecycle).must_equal(
          preStop: "OLD"
        )
      end
    end

    describe "HorizontalPodAutoscaler" do
      before do
        raw_template[:kind] = "HorizontalPodAutoscaler"
        raw_template[:spec][:scaleTargetRef] = {}
      end

      it "matches the resource name" do
        template.to_hash.dig_fetch(:spec, :scaleTargetRef, :name).must_equal("test-app-server")
      end
    end

    describe "blue-green" do
      before do
        doc.kubernetes_role.blue_green = true
        doc.kubernetes_release.blue_green_color = 'green'
      end

      it "modifies the service" do
        raw_template[:kind] = 'Service'
        template.to_hash.dig_fetch(:spec, :selector, :blue_green).must_equal 'green'
      end

      it "modifies the resource" do
        hash = template.to_hash
        hash.dig_fetch(:metadata, :name).must_equal 'test-app-server-green'
        hash.dig_fetch(:spec, :template, :spec, :containers, 0, :env).must_include(name: "BLUE_GREEN", value: "green")
        hash.dig_fetch(:metadata, :labels, :blue_green).must_equal 'green'
        hash.dig_fetch(:spec, :selector, :matchLabels, :blue_green).must_equal 'green'
        hash.dig_fetch(:spec, :template, :metadata, :labels, :blue_green).must_equal 'green'
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

  describe "#images" do
    it "finds images from containers" do
      template.images.must_equal ["docker-registry.zende.sk/truth_service:latest"]
    end

    it "finds images from init-containers" do
      add_init_container image: 'init-container'
      template.images.must_equal ["docker-registry.zende.sk/truth_service:latest", "init-container"]
    end
  end
end
