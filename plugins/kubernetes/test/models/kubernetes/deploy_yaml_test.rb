require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployYaml do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }
  let(:yaml) { Kubernetes::DeployYaml.new(doc) }

  before { kubernetes_fake_raw_template }

  describe "#resource_name" do
    it 'is deployment' do
      yaml.resource_name.must_equal 'deployment'
    end

    it 'knows if it is a DaemonSet' do
      yaml.send(:template).kind = 'DaemonSet'
      yaml.resource_name.must_equal 'daemon_set'
    end
  end

  describe "#to_hash" do
    it "works" do
      result = yaml.to_hash
      result.size.must_equal 3

      spec = result.fetch(:spec)
      spec.fetch(:uniqueLabelKey).must_equal "rc_unique_identifier"
      spec.fetch(:replicas).must_equal doc.replica_target
      spec.fetch(:template).fetch(:metadata).fetch(:labels).must_equal(
        pre_defined: "foobar",
        release_id: doc.kubernetes_release_id.to_s,
        project_id: doc.kubernetes_release.project_id.to_s,
        role_id: doc.kubernetes_role_id.to_s,
        role_name: "app_server",
        deploy_group_id: doc.deploy_group_id.to_s,
        deploy_group_namespace: "pod1"
      )

      metadata = result.fetch(:metadata)
      metadata.fetch(:namespace).must_equal 'pod1'
      metadata.fetch(:labels).must_equal(
        project_id: doc.kubernetes_release.project_id.to_s,
        role_name: "app_server",
        deploy_group_namespace: "pod1"
      )

      spec.fetch(:template).fetch(:spec).fetch(:containers).first.must_equal(
        image: 'docker-registry.example.com/test@sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c',
        resources: {
          limits:{
            memory: "100Mi",
            cpu: 1.0
          }
        }
      )
    end

    it "fails without selector" do
      assert doc.raw_template.sub!('selector:', 'no_selector:')
      e = assert_raises Samson::Hooks::UserError do
        yaml.to_hash
      end
      e.message.must_include 'selector'
    end

    describe "deployment" do
      it "fails when deployment section is missing" do
        assert doc.raw_template.sub!('Deployment', 'Foobar')
        e = assert_raises Samson::Hooks::UserError do
          yaml.to_hash
        end
        e.message.must_include "has 0 Deployment sections, having 1 section is valid"
      end

      it "fails when multiple deployment sections are present" do
        doc.raw_template.replace("#{doc.raw_template}\n#{doc.raw_template}")
        e = assert_raises Samson::Hooks::UserError do
          yaml.to_hash
        end
        e.message.must_include "has 2 Deployment sections, having 1 section is valid"
      end
    end

    describe "containers" do
      it "fails without containers" do
        assert doc.raw_template.sub!("      containers:\n      - {}", '')
        e = assert_raises Samson::Hooks::UserError do
          yaml.to_hash
        end
        e.message.must_include "has 0 containers, having 1 section is valid"
      end

      it "fails with multiple containers" do
        assert doc.raw_template.sub!("containers:\n      - {}", "containers:\n      - {}\n      - {}")
        e = assert_raises Samson::Hooks::UserError do
          yaml.to_hash
        end
        e.message.must_include "has 2 containers, having 1 section is valid"
      end
    end

    describe "daemon_set" do
      it "does not add replicas since they are not supported" do
        yaml.send(:template).kind = 'DaemonSet'
        result = yaml.to_hash
        refute result.key?(:replicas)
      end
    end
  end
end

