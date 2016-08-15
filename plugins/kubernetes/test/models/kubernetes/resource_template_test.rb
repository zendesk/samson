# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ResourceTemplate do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }
  let(:template) { Kubernetes::ResourceTemplate.new(doc) }

  before do
    kubernetes_fake_raw_template
    doc.kubernetes_release.deploy_id = 123
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

    it "overrides the name" do
      template.to_hash[:metadata][:name].must_equal 'test-app-server'
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
      let(:secret_key) { "global/global/global/bar" }

      around do |test|
        klass = Kubernetes::ResourceTemplate
        silence_warnings { klass.const_set(:SIDECAR_IMAGE, "docker-registry.example.com/foo:bar") }
        test.call
        silence_warnings { klass.const_set(:SIDECAR_IMAGE, nil) }
      end

      before do
        old_metadata = "role: some-role\n    "
        new_metadata = "role: some-role\n      annotations:\n        secret/FOO: bar\n    "
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
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_include "Failed to resolve secret keys:\n\tbar (tried: production/foo/pod1/bar"
      end

      it "fails to find multiple secret needed by the sidecar, but shows them all at once" do
        assert doc.raw_template.sub!("secret/FOO: bar", "secret/FOO: bar\n        secret/BAR: baz")
        SecretStorage.delete(secret_key)
        e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
        e.message.must_include "bar (tried: production/foo/pod1/bar"
        e.message.must_include "baz (tried: production/foo/pod1/baz"
      end

      describe "scopes" do
        before do
          SecretStorage.stubs(:read).returns(true)
        end

        it "looks up by only the key" do
          SecretStorage.expects(:read_multi).returns('global/global/global/bar' => 'xyz')
          template.to_hash[:spec][:template][:metadata][:annotations][:'secret/FOO'].
            must_equal "global/global/global/bar"
        end

        it "fails when unable to find by onl key" do
          SecretStorage.expects(:read_multi).returns({})
          e = assert_raises(Samson::Hooks::UserError) { template.to_hash }
          # order is important here and should not change
          priority = [
            "production/foo/pod1/bar",
            "global/foo/pod1/bar",
            "production/global/pod1/bar",
            "global/global/pod1/bar",
            "production/foo/global/bar",
            "global/foo/global/bar",
            "production/global/global/bar",
            "global/global/global/bar"
          ]
          e.message.must_equal "Failed to resolve secret keys:\n\tbar (tried: #{priority.join(", ")})"
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
