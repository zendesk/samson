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
  let(:project) { doc.kubernetes_release.project }

  before do
    doc.send(:resource_template=, YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml')))
    doc.kubernetes_release.builds = [builds(:docker_build)]

    stub_request(:get, %r{http://foobar.server/api/v1/namespaces/\S+/secrets}).to_return(body: {items: []}.to_json)

    Samson::Secrets::VaultClientManager.any_instance.stubs(:client).
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
        project_id: project.id.to_s,
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

    it "does not modify passed in template" do
      old = raw_template.deep_dup
      template.to_hash
      raw_template.must_equal old
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

    describe "imagePullSecrets" do
      let(:url) { "http://foobar.server/api/v1/namespaces/pod1/secrets" }
      let(:reply) do
        {
          items: [
            {type: "kubernetes.io/dockercfg", metadata: {name: 'a'}},
            {type: "kubernetes.io/nope", metadata: {name: 'b'}},
            {type: "kubernetes.io/dockerconfigjson", metadata: {name: 'c'}},
            {type: "kubernetes.io/dockerNotValidConfigThing", metadata: {name: 'd'}}
          ]
        }
      end

      it "gets set" do
        assert_request(:get, url, to_return: {body: reply.to_json}) do
          template.to_hash[:spec][:template][:spec][:imagePullSecrets].must_equal(
            [{name: 'a'}, {name: 'c'}]
          )
        end
      end

      it "retries when it fails" do
        assert_request(:get, url, to_return: [{status: 500}, {body: reply.to_json}]) do
          template.to_hash[:spec][:template][:spec][:imagePullSecrets].must_equal(
            [{name: 'a'}, {name: 'c'}]
          )
        end
      end
    end

    it "sets revisionHistoryLimit" do
      template.to_hash[:spec][:revisionHistoryLimit].must_equal 1
    end

    it "keeps namespaces when cluster-service is set" do
      raw_template[:metadata][:namespace] = "default"
      raw_template[:metadata][:labels][:"kubernetes.io/cluster-service"] = 'true'
      template.to_hash[:metadata][:namespace].must_equal 'default'
    end

    it "keeps namespaces when keep_namespace is set" do
      raw_template[:metadata][:namespace] = "default"
      raw_template[:metadata][:annotations] = {"samson/keep_namespace": 'true'}
      template.to_hash[:metadata][:namespace].must_equal 'default'
    end

    it "can verify without builds" do
      doc.kubernetes_release.builds = []
      template.to_hash(verification: true)
    end

    it "adds deploy url to resource and templates" do
      result = template.to_hash
      result.dig(:metadata, :annotations, :"samson/deploy_url").must_equal doc.kubernetes_release.deploy.url
      result.dig(:spec, :template, :metadata, :annotations, :"samson/deploy_url").
        must_equal doc.kubernetes_release.deploy.url
    end

    it "sets replicas for templates" do
      raw_template[:kind] = "foobar"
      raw_template[:spec].delete :replicas
      raw_template[:spec][:template][:spec][:replicas] = 1
      result = template.to_hash
      result[:spec][:replicas].must_be_nil
      result[:spec][:template][:spec][:replicas].must_equal 2
    end

    it "sets name for unknown non-primary kinds" do
      raw_template[:kind] = "foobar"
      raw_template[:spec][:template][:spec].delete(:containers)
      template.to_hash[:metadata][:name].must_equal "test-app-server"
    end

    it "keeps resource name when keep_name is set" do
      raw_template[:metadata][:name] = "foobar"
      raw_template[:metadata][:annotations] = {"samson/keep_name": 'true'}
      template.to_hash[:metadata][:name].must_equal 'foobar'
    end

    ['CustomResourceDefinition', 'APIService'].each do |kind|
      it "does not set override name for #{kind} since it follows a fixed naming pattern" do
        raw_template[:kind] = kind
        raw_template[:metadata].delete(:namespace)
        template.to_hash[:metadata][:name].must_equal "some-project-rc"
        template.to_hash[:metadata][:namespace].must_equal nil
      end
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
        doc.replica_target = 1
        raw_template[:spec].delete(:template)
        raw_template[:spec].delete(:selector)
        labels.must_equal ["foo", nil, nil, nil]
      end

      it "overrides project label in service" do
        raw_template[:spec][:selector][:project] = "bar"
        labels.must_equal ["foo", "foo", "foo", "foo"]
      end
    end

    describe "configmap" do
      it "only modifies namespace since there is no template" do
        raw_template[:kind] = "ConfigMap"
        raw_template.delete(:spec)
        raw_template[:metadata][:namespace] = 'old'
        result = template.to_hash
        result[:metadata][:namespace].must_equal 'pod1'
        refute result[:spec]
      end
    end

    describe "service" do
      before { raw_template[:kind] = 'Service' }

      it "does not override with blank service name" do
        doc.kubernetes_role.update_column(:service_name, '') # user left field empty
        template.to_hash[:metadata][:name].must_equal 'some-project-rc'
      end

      it "fills name" do
        doc.kubernetes_role.update_column(:service_name, 'custom')
        template.to_hash[:metadata][:name].must_equal 'custom'
      end

      it "keeps service name when keep_name is set" do
        raw_template[:metadata][:name] = "foobar"
        raw_template[:metadata][:annotations] = {"samson/keep_name": 'true'}
        template.to_hash[:metadata][:name].must_equal 'foobar'
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
          template.instance_variable_get(:@template)[:metadata][:name] = 'foo-other'
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
      let(:build) { builds(:docker_build) }
      let(:image) { build.docker_repo_digest }

      describe "image manipulation" do
        it "overrides image" do
          container.fetch(:image).must_equal image
        end

        it "does not override image when 'none' is passed as dockerfile" do
          raw_template[:spec][:template][:spec][:containers][0][:'samson/dockerfile'] = 'none'
          raw_template[:spec][:template][:spec][:containers][0][:image] = 'foo'

          result # trigger set_docker_image_for_containers
          container.fetch(:image).must_equal 'foo'
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
            e.message.must_equal(
              "Did not find build for dockerfile \"Dockerfile.new\".\n" \
              "Found builds: [[\"Dockerfile\"]].\n" \
              "Project builds URL: http://www.test-url.com/projects/foo/builds"
            )
          end
        end

        it "allows selecting dockerfile for init containers" do
          add_init_container "samson/dockerfile": 'Dockerfile', name: 'foo'
          init_containers[0].must_equal("samson/dockerfile" => "Dockerfile", "image" => image, "name" => "foo")
        end

        it "raises if an init container does not specify a dockerfile" do
          add_init_container a: 1, "samson/dockerfile": 'Foo', name: 'foo'
          e = assert_raises(Samson::Hooks::UserError) { init_containers[0] }
          e.message.must_equal(
            "Did not find build for dockerfile \"Foo\".\nFound builds: [[\"Dockerfile\"]].\n"\
            "Project builds URL: http://www.test-url.com/projects/foo/builds"
          )
        end

        it "overrides Always imagePullPolicy since it does not make sense and slows us down" do
          add_init_container imagePullPolicy: 'Always', name: 'foo'
          init_containers[0]["imagePullPolicy"].must_equal "IfNotPresent"
        end

        describe "when project does not build images" do
          before do
            project.docker_image_building_disabled = true
            build.update_column(:image_name, 'truth_service')
          end

          it "fills matching image from builds" do
            container.fetch(:image).must_equal image
          end

          it "fails when build is not found" do
            build.update_column(:image_name, 'nope')
            e = assert_raises(Samson::Hooks::UserError) { container.fetch(:image).must_equal image }
            e.message.must_include "Did not find build for image_name \"truth_service\""
          end
        end
      end

      describe '#modify_init_container' do
        def add_init_contnainer_new_syntax(container)
          raw_template[:spec][:template][:spec][:initContainers] = [container]
        end

        let(:spec_annotation_containers) do
          JSON.parse(result.dig(:spec, :template, :metadata, :annotations, init_container_key) || '[]')
        end

        let(:spec_init_containers) { result.dig(:spec, :template, :spec, :initContainers) || [] }

        it 'sets init containers in annotations if using < 1.6.0 k8s server version' do
          add_init_container "samson/dockerfile": 'Dockerfile', name: 'foo'
          spec_annotation_containers[0].must_equal(
            "samson/dockerfile" => "Dockerfile",
            "image" => image,
            "name" => "foo"
          )
        end

        it 'sets init containers using updated syntax to old syntax if using < 1.6.0 k8s server version' do
          add_init_contnainer_new_syntax('samson/dockerfile': 'Dockerfile', name: 'foo')

          spec_init_containers.must_equal([])
          spec_annotation_containers[0].must_equal(
            "samson/dockerfile" => "Dockerfile",
            "image" => image,
            "name" => "foo"
          )
        end

        it 'does not set init containers if there are none' do
          spec_annotation_containers.must_equal([])
        end

        describe 'using new server version' do
          before do
            stub_request(:get, 'http://foobar.server/version').to_return(body: '{"gitVersion": "v1.6.0"}')
          end

          it 'sets init containers in spec if using >= 1.6.0 k8s server version' do
            add_init_contnainer_new_syntax("samson/dockerfile": 'Dockerfile', name: 'foo')
            spec_init_containers[0].must_equal('samson/dockerfile': "Dockerfile", image: image, name: 'foo')
          end

          it 'sets init containers using old syntax to new syntax if using >= 1.6.0 k8s server version' do
            add_init_container "samson/dockerfile": 'Dockerfile', name: 'foo'

            spec_annotation_containers.must_equal([])
            spec_init_containers[0].must_equal('samson/dockerfile': "Dockerfile", image: image, name: 'foo')
          end

          it 'does not set init containers if there are none' do
            spec_init_containers.must_equal([])
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

      it "does not set cpu limit when using no_cpu_limit" do
        doc.no_cpu_limit = true
        container.fetch(:resources).must_equal(
          requests: {
            cpu: 0.5,
            memory: "50M"
          },
          limits: {
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
        Samson::Hooks.with_callback(:deploy_group_env, ->(p, dg, _) { {FromEnv: "#{p.name}-#{dg.name}"} }) do
          container.fetch(:env).must_include(name: 'FromEnv', value: 'Foo-Pod1')
        end
      end

      it "adds env from deploy_env hook" do
        Samson::Hooks.with_callback(:deploy_env, ->(d) { {FromEnv: "$FOO secret://noooo #{d.user.name}"} }) do
          container.fetch(:env).must_include(name: 'FromEnv', value: '$FOO secret://noooo Super Admin')
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
        before { raw_template[:spec][:template][:spec][:containers] = [{name: 'foo'}, {name: 'bar'}] }

        it "allows multiple containers, even though they will not be properly replaced" do
          template.to_hash
        end

        it "fills all container envs" do
          template.to_hash
          containers[0][:env].must_equal containers[1][:env]
        end
      end
    end

    describe "secret-puller-containers" do
      let(:secret_key) { "global/global/global/bar" }
      let(:template_env) { template.to_hash[:spec][:template][:spec][:containers].first[:env] }
      let!(:vault_server) { create_vault_server(name: 'pod1') }

      around do |test|
        stub_const Kubernetes::TemplateFiller, :SECRET_PULLER_IMAGE, "docker-registry.example.com/foo:bar", &test
      end

      before do
        raw_template[:spec][:template][:metadata][:annotations] = {"secret/FOO": "bar"}
        create_secret(secret_key)
        Samson::Secrets::VaultClientManager.any_instance.unstub(:client)
        deploy_groups(:pod1).update_column(:vault_server_id, vault_server.id)
      end

      it "adds secret puller container" do
        init_containers.first['name'].must_equal('secret-puller')
        init_containers.first['env'].must_equal(
          [
            {"name" => "VAULT_ADDR", "value" => "http://vault-land.com"},
            {"name" => "VAULT_SSL_VERIFY", "value" => "false"},
            {"name" => "VAULT_MOUNT", "value" => "secret"},
            {"name" => "VAULT_PREFIX", "value" => "apps"},
            {"name" => "VAULT_KV_V2", "value" => "false"}
          ]
        )

        # secrets got resolved?
        template.to_hash[:spec][:template][:metadata][:annotations].select { |k, _| k.match?("secret") }.must_equal(
          "secret/FOO": "global/global/global/bar",
          "container-secret-puller-samson/dockerfile": "none"
        )
      end

      it "adds vault kv v2 hint so puller knows to use the new api" do
        vault_server.update_column :versioned_kv, true
        init_containers.first['env'].last.must_equal "name" => "VAULT_KV_V2", "value" => "true"
      end

      it "fails when vault is not configured" do
        with_env('SECRET_STORAGE_BACKEND': "Samson::Secrets::HashicorpVaultBackend") do
          Samson::Secrets::VaultClientManager.instance.expects(:client).raises("Could not find Vault config for pod1")
          e = assert_raises { template.to_hash }
          e.message.must_equal "Could not find Vault config for pod1"
        end
      end

      describe 'when using vault' do
        let(:vault_env) { template_env.detect { |h| break h.fetch(:value) if h.fetch(:name) == "VAULT_ADDR" } }

        with_env(SECRET_STORAGE_BACKEND: "Samson::Secrets::HashicorpVaultBackend")

        it "does not add the vault server if VAULT_ADDR is not required" do
          refute vault_env
        end

        describe 'when vault address is required' do
          before { raw_template[:spec][:template][:metadata][:annotations] = {"samson/required_env": 'VAULT_ADDR'} }

          it "adds the vault server address to the containers env" do
            vault_env.must_equal "http://vault-land.com"
          end

          it "does not overwrite user defined value" do
            EnvironmentVariable.create!(parent: projects(:test), name: 'VAULT_ADDR', value: 'hello')
            vault_env.must_equal 'hello'
          end
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

      describe "converting secrets in env to annotations" do
        def secret_annotations(hash)
          hash[:spec][:template][:metadata][:annotations].select { |k, _| k.match?("secret") }
        end

        with_env SECRET_ENV_AS_ANNOTATIONS: 'true'

        before do
          create_secret 'global/global/global/foo'
          EnvironmentVariable.create!(parent: project, name: 'BAR', value: 'secret://foo')
          EnvironmentVariable.create!(parent: project, name: 'BAZ', value: 'nope-secret://foo')
        end

        it "coverts secrets in env to annotations" do
          hash = template.to_hash

          # secrets got resolved?
          secret_annotations(hash).must_equal(
            "secret/FOO": "global/global/global/bar",
            "secret/BAR": "global/global/global/foo",
            "container-secret-puller-samson/dockerfile": "none"
          )

          # keeps the unresolved around for debugging
          env = hash[:spec][:template][:spec][:containers][0][:env]
          env.select { |e| ["BAR", "BAZ"].include?(e[:name]) }.must_equal [{name: "BAZ", value: "nope-secret://foo"}]
        end

        it "ignores when annotations would be overwritten with the same value" do
          raw_template[:spec][:template][:metadata][:annotations] = {"secret/BAR": 'foo'}
          template.to_hash
        end

        it "blows up when annotations would be overwritten with a different value" do
          raw_template[:spec][:template][:metadata][:annotations] = {"secret/BAR": 'foo2'}
          e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
          e.message.must_include "Annotation key secret/BAR is already set to foo2, cannot set it via environment"
        end

        it "does not blow up when using multiple containers with the same env" do
          raw_template[:spec][:template][:spec][:containers] = [{name: 'foo'}, {name: 'bar'}]
          hash = template.to_hash

          # secrets got resolved?
          secret_annotations(hash).must_equal(
            "secret/FOO": "global/global/global/bar",
            "secret/BAR": "global/global/global/foo",
            "container-secret-puller-samson/dockerfile": "none"
          )

          # keeps the unresolved around for debugging
          envs = hash[:spec][:template][:spec][:containers].map { |c| c[:env] }
          envs.each do |env|
            env.select { |e| ["BAR", "BAZ"].include?(e[:name]) }.must_equal [{name: "BAZ", value: "nope-secret://foo"}]
          end
        end

        it "works when no other secret annotation was set" do
          raw_template[:spec][:template][:metadata][:annotations].clear
          secret_annotations(template.to_hash).must_equal(
            "secret/BAR": "global/global/global/foo",
            "container-secret-puller-samson/dockerfile": "none"
          )
        end
      end
    end

    describe "daemon_set" do
      before do
        raw_template[:kind] = 'DaemonSet'
        raw_template[:spec].delete(:replicas)
        doc.replica_target = 1
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
        doc.replica_target = 1
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

      it "complains on invalid replica settings" do
        doc.replica_target = 0
        assert_raises(Samson::Hooks::UserError) { template.to_hash }

        doc.replica_target = 2
        assert_raises(Samson::Hooks::UserError) { template.to_hash }
      end

      it "allows deletion" do
        doc.replica_target = 0
        doc.delete_resource = true
        template.to_hash
      end
    end

    describe "cronjob" do
      before do
        raw_template.replace(YAML.safe_load(read_kubernetes_sample_file('kubernetes_cron_job.yml')).deep_symbolize_keys)
        doc.replica_target = 1
      end

      it "works" do
        template.to_hash
      end
    end

    describe "preStop" do
      it "does not add preStop" do
        refute template.to_hash.dig_fetch(:spec, :template, :spec, :containers, 0).key?(:lifecycle)
      end

      describe "with preStop enabled" do
        around { |t| stub_const Kubernetes::TemplateFiller, :KUBERNETES_ADD_PRESTOP, true, &t }

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

        it "does not add preStop when opted out" do
          raw_template.dig_fetch(:spec, :template, :spec, :containers, 0)[:"samson/preStop"] = "disabled"
          refute template.to_hash.dig_fetch(:spec, :template, :spec, :containers, 0).key?(:lifecycle)
        end
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

      it "sets the name" do
        template.to_hash.dig_fetch(:metadata, :name).must_equal("test-app-server")
      end
    end

    describe "PodDisruptionBudget" do
      before do
        raw_template[:kind] = 'PodDisruptionBudget'
        raw_template[:spec][:template][:spec].delete(:containers)
      end

      it "modified name" do
        hash = template.to_hash
        hash.dig_fetch(:metadata, :name).must_equal 'test-app-server'
        refute hash.dig(:spec, :selector, :matchLabels).key?(:blue_green)
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

      it "modified budgets so we do not get errors when 2 budgets match the same pod" do
        raw_template[:kind] = 'PodDisruptionBudget'
        raw_template[:spec].delete(:template)
        hash = template.to_hash
        hash.dig_fetch(:metadata, :name).must_equal 'test-app-server-green'
        hash.dig_fetch(:spec, :selector, :matchLabels, :blue_green).must_equal 'green'
      end
    end

    describe "set_via_env_json" do
      let!(:environment) { EnvironmentVariable.create!(parent: project, name: "FOO", value: '"bar"') }

      before do
        raw_template[:metadata][:annotations] = {
          "samson/set_via_env_json-spec.foo" => "FOO"
        }
      end

      it "sets simple" do
        template.to_hash[:spec][:foo].must_equal "bar"
      end

      it "supports - mode to make name valid dns name when user uses /" do
        raw_template[:metadata][:annotations] = {
          "samson-set-via-env-json-spec.foo" => "FOO"
        }
        template.to_hash[:spec][:foo].must_equal "bar"
      end

      it "sets podless roles" do
        raw_template[:spec] = {}
        template.to_hash[:spec][:foo].must_equal "bar"
      end

      it "sets annotations with ." do
        raw_template[:metadata][:annotations] = {
          "samson/set_via_env_json-metadata.annotations.foo.bar/baz" => "FOO"
        }
        template.to_hash[:metadata][:annotations][:"foo.bar/baz"].must_equal "bar"
      end

      it "sets labels with ." do
        raw_template[:metadata][:annotations] = {
          "samson/set_via_env_json-metadata.labels.foo.bar/baz" => "FOO"
        }
        template.to_hash[:metadata][:labels][:"foo.bar/baz"].must_equal "bar"
      end

      it "sets in arrays" do
        raw_template[:metadata][:annotations] = {
          "samson/set_via_env_json-spec.template.spec.containers.0.foo" => "FOO"
        }
        template.to_hash.dig(:spec, :template, :spec, :containers, 0, :foo).must_equal "bar"
      end

      it "fails nicely when missing" do
        raw_template[:metadata][:annotations] = {
          "samson/set_via_env_json-foo.bar.foo" => "FOO"
        }
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_equal(
          "Unable to set key samson/set_via_env_json-foo.bar.foo: KeyError key not found: [:foo, :bar]"
        )
      end

      it "fails nicely with invalid json" do
        environment.update_column(:value, 'foo')
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_equal(
          "Unable to set key samson/set_via_env_json-spec.foo: JSON::ParserError 765: unexpected token at 'foo'"
        )
      end

      it "fails nicely with env is missing" do
        environment.update_column(:name, 'BAR')
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_equal "Unable to set key samson/set_via_env_json-spec.foo: KeyError key not found: \"FOO\""
      end
    end
  end

  describe "#verify" do
    it "checks env and secrets" do
      template.expects(:verify_env)
      template.expects(:set_secrets)
      template.verify
    end

    it "can verify when resolving secret envs" do
      with_env SECRET_ENV_AS_ANNOTATIONS: 'true' do
        template.verify
      end
    end
  end

  describe "#verify_env" do
    it "passes when nothing is required" do
      template.expects(:set_env).never # does not call expensive stuff if nothing is required
      template.send(:verify_env)
    end

    it "passes when resource has no containers" do
      raw_template.delete :spec
      template.send(:verify_env)
    end

    describe "when something is required" do
      let(:pod_annotations) { raw_template[:spec][:template][:metadata][:annotations] = {} }

      before { pod_annotations[:"samson/required_env"] = 'FOO' }

      it "fails when value is missing" do
        e = assert_raises Samson::Hooks::UserError do
          template.send(:verify_env)
        end
        e.message.must_equal "Missing env variables [\"FOO\"]"
      end

      it "fails when multiple values are missing" do
        pod_annotations[:"samson/required_env"] = 'FOO BAR,BAZ,  FOO2    FOO3'
        e = assert_raises Samson::Hooks::UserError do
          template.send(:verify_env)
        end
        e.message.must_include "Missing env variables [\"FOO\", \"BAR\", \"BAZ\", \"FOO2\", \"FOO3\"]"
      end

      it "passes when missing value is filled out" do
        EnvironmentVariable.create!(parent: projects(:test), name: 'FOO', value: 'BAR')
        template.send(:verify_env)
      end

      it "works without a deploy when doing template verification" do
        EnvironmentVariable.create!(parent: projects(:test), name: 'FOO', value: 'BAR')
        doc.kubernetes_release.deploy = nil
        template.send(:verify_env)
      end
    end
  end

  describe "#build_selectors" do
    it "returns Dockerfile by default" do
      template.build_selectors.must_equal [["Dockerfile", nil]]
    end

    it "allows selecting a dockerfile" do
      raw_template[:spec][:template][:spec][:containers][0][:'samson/dockerfile'] = 'Bar'
      template.build_selectors.must_equal [["Bar", nil]]
    end

    it "ignores images that should not be built" do
      raw_template[:spec][:template][:spec][:containers][0][:'samson/dockerfile'] = 'none'
      template.build_selectors.must_equal []
    end

    it "ignores images that should not be built via annotations" do
      raw_template[:spec][:template][:metadata][:annotations] = {'container-some-project-samson/dockerfile': 'none'}
      template.build_selectors.must_equal []
    end

    it "returns empty when resource has no containers" do
      raw_template.delete :spec
      template.build_selectors.must_equal []
    end

    it "calls vulnerability scanner for hardcoded images" do
      raw_template[:spec][:template][:spec][:containers][0][:'samson/dockerfile'] = 'none'
      raw_template[:spec][:template][:spec][:containers][0][:image] = 'foo.com/example/bar'
      SamsonGcloud.expects(:ensure_docker_image_has_no_vulnerabilities)
      template.build_selectors
    end

    describe "when user selected to not enforce docker images" do
      with_env KUBERNETES_ADDITIONAL_CONTAINERS_WITHOUT_DOCKERFILE: 'true'

      it "defaults to no dockerfile for additional containers" do
        raw_template[:spec][:template][:spec][:containers] << {image: 'baz', name: 'foo'}
        template.build_selectors.must_equal [["Dockerfile", nil]]
      end

      it "still allows selecting a dockerfile" do
        raw_template[:spec][:template][:spec][:containers] << {'samson/dockerfile': 'bar', image: 'baz', name: 'foo'}
        template.build_selectors.must_equal [["Dockerfile", nil], ["bar", nil]]
      end
    end

    describe "when only images are supported" do
      before { project.docker_image_building_disabled = true }

      it "finds images from containers" do
        template.build_selectors.must_equal [[nil, "docker-registry.zende.sk/truth_service:latest"]]
      end

      it "finds images from init-containers" do
        add_init_container image: 'init-container', name: 'foo'
        template.build_selectors.must_equal(
          [[nil, "docker-registry.zende.sk/truth_service:latest"], [nil, "init-container"]]
        )
      end

      it "does not include images that should not be built" do
        raw_template[:spec][:template][:spec][:containers][0][:'samson/dockerfile'] = 'none'
        raw_template[:spec][:template][:spec][:containers] << {'samson/dockerfile': 'bar', image: 'baz', name: 'baz'}

        template.build_selectors.must_equal [[nil, 'baz']]
      end
    end
  end
end
