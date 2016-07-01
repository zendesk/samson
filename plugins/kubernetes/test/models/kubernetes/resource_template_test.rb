require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ResourceTemplate do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }
  let(:template) { Kubernetes::ResourceTemplate.new(doc) }

  before do
    kubernetes_fake_raw_template
    doc.kubernetes_release.deploy_id = 123
  end

  describe "#resource_kind" do
    it 'is deployment' do
      template.resource_kind.must_equal 'deployment'
    end

    it 'knows if it is a DaemonSet' do
      template.send(:template)[:kind] = 'DaemonSet'
      template.resource_kind.must_equal 'daemon_set'
    end
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
        'tag' => "user-feature",
        'deploy_group' => 'foo-bar',
        'role' => 'some-role'
      )
    end

    describe "containers" do
      let(:result) { template.to_hash }
      let(:container) { result.fetch(:spec).fetch(:template).fetch(:spec).fetch(:containers).first }

      it "overrides image" do
        container.fetch(:image).must_equal(
          'docker-registry.example.com/test@sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c'
        )
      end

      it "copies resource values" do
        container.fetch(:resources).must_equal(
          'limits' => {
            'memory' => "100Mi",
            'cpu' => 1.0
          }
        )
      end

      it "fills then environment with string values" do
        env = container.fetch(:env)
        env.map { |x| x.fetch(:name) }.sort.must_equal(
          [:REVISION, :TAG, :PROJECT, :ROLE, :DEPLOY_ID, :DEPLOY_GROUP, :POD_NAME, :POD_NAMESPACE, :POD_IP].sort
        )
        env.map { |x| x[:value] }.map(&:class).map(&:name).sort.uniq.must_equal(["NilClass", "String"])
      end

      # https://github.com/zendesk/samson/issues/966
      it "allows multiple containers, even though they will not be properly replaced" do
        assert doc.raw_template.sub!("containers:\n", "containers:\n      - {}\n")
        template.to_hash
      end

      it "merges existing env settings" do
        template.send(:template)[:spec][:template][:spec][:containers][0][:env] = [{name: 'Foo', value: 'Bar'}]
        keys = container.fetch(:env).map(&:to_h).map { |x| x.symbolize_keys.fetch(:name) }
        keys.must_include 'Foo'
        keys.size.must_be :>, 5
      end
    end

    describe "secret-sidecar-containers" do
      with_env(VAULT_ADDR: "somehostontheinternet", VAULT_SSL_VERIFY: "false")

      let(:secret_key) { 'production/foo/snafu/bar' }

      around do |test|
        klass = Kubernetes::ResourceTemplate
        silence_warnings { klass.const_set(:SIDECAR_IMAGE, "docker-registry.example.com/foo:bar") }
        test.call
        silence_warnings { klass.const_set(:SIDECAR_IMAGE, nil) }
      end

      before do
        old_metadata = "role: some-role\n    "
        new_metadata = "role: some-role\n      annotations:\n        secret/FOO: #{secret_key}\n    "
        assert doc.raw_template.sub!(old_metadata, new_metadata)

        SecretStorage.write(secret_key, value: 'something', user_id: 123)
      end

      it "creates a sidecar" do
        template.to_hash[:spec][:template][:spec][:containers].last[:name].must_equal('secret-sidecar')
      end

      it "adds to existing volume definitions in the sidecar" do
        assert doc.raw_template.sub!(
          /containers:\n(    .*\n)+/m,
          "containers:\n      - {}\n      volumes:\n      - {}\n      - {}\n"
        )
        template.to_hash[:spec][:template][:spec][:volumes].count.must_equal 5
      end

      it "adds to existing volume definitions in the primary container" do
        assert doc.raw_template.sub!(
          /containers:\n(    .*\n)+/m,
          "containers:\n      - :name: foo\n        :volumeMounts:\n        - :name: bar\n"
        )
        template.to_hash[:spec][:template][:spec][:containers].first[:volumeMounts].count.must_equal 2
      end

      it "adds to existing volume definitions in the primary container when volumeMounts is empty" do
        assert doc.raw_template.sub!(
          /containers:\n(    .*\n)+/m,
          "containers:\n      - :name: foo\n        :volumeMounts:\n"
        )
        template.to_hash[:spec][:template][:spec][:containers].first[:volumeMounts].count.must_equal 1
      end

      it "creates no sidecar when there are no secrets" do
        assert doc.raw_template.sub!('secret/', 'public/')
        template.to_hash[:spec][:template][:spec][:containers].map { |c| c[:name] }.must_equal(['some-project'])
      end

      it "fails to find a secret needed by the sidecar" do
        SecretStorage.delete(secret_key)
        e = assert_raises Samson::Hooks::UserError do
          template.to_hash
        end
        e.message.must_include "secret/FOO with key production/foo/snafu/bar could not be found"
      end

      describe "scopes" do
        before do
          SecretStorage.stubs(:read).returns(true)
        end

        it "secret is scoped correctly" do
          assert doc.raw_template.sub!(secret_key, '${ENV}/foo/${DEPLOY_GROUP}/bar')
          template.to_hash[:spec][:template][:metadata][:annotations][:'secret/FOO'].
            must_equal "production/foo/pod1/bar"
        end

        it "does not effect a non secret annotation" do
          assert doc.raw_template.sub!(secret_key, "#{secret_key}\n        annotation_key: somevalueforthekey")
          template.to_hash[:spec][:template][:metadata][:annotations][:annotation_key].
            must_equal "somevalueforthekey"
        end
      end
    end

    describe "daemon_set" do
      it "does not add replicas since they are not supported" do
        template.send(:template)[:kind] = 'DaemonSet'
        result = template.to_hash
        refute result.key?(:replicas)
      end
    end
  end
end
