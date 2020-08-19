# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Namespace do
  let(:namespace) { kubernetes_namespaces(:test) }
  let(:project) { projects(:test) }

  describe "validations" do
    it "is valid" do
      assert_valid namespace
    end

    it "is not valid when name is capitalized" do
      namespace.name = "Test"
      refute_valid namespace
    end

    it "is not valid with empty template" do
      namespace.template = ""
      refute_valid namespace
      namespace.errors.full_messages.must_equal ["Template needs to be set"]
    end

    it "is not valid with non-hash template" do
      namespace.template = "true"
      refute_valid namespace
      namespace.errors.full_messages.must_equal ["Template needs to be a Hash"]
    end

    it "is not valid with invalid template" do
      namespace.template = {a: 1}.to_yaml
      refute_valid namespace
      namespace.errors.full_messages.must_equal ["Template needs to be valid yaml"]
    end

    it "is not valid without a team" do
      namespace.template = {"metadata" => {"foo" => "foo"}}.to_yaml
      refute_valid namespace
      namespace.errors.full_messages.must_equal ["Template needs metadata.labels.team"]
    end
  end

  describe "#ensure_unused" do
    it "allows deletion when unused" do
      assert namespace.destroy
    end

    it "does not allow deletion when used" do
      namespace.projects << projects(:test)
      refute namespace.destroy
    end
  end

  describe "#remove_configured_resource_names" do
    it "clean existing roles" do
      assert_difference "Audited::Audit.count", 3 do
        namespace.update!(project_ids: [project.id]) # do what controller does
      end
      role = kubernetes_roles(:app_server)
      role.resource_name.must_be_nil
      role.service_name.must_be_nil
    end

    it "skips clean roles" do
      Kubernetes::Role.update_all(resource_name: nil, service_name: nil)
      assert_difference "Audited::Audit.count", 1 do
        project.create_kubernetes_namespace!(name: "bar", template: "metadata:\n  labels:\n    team: foo")
      end
    end
  end

  describe "#manifest" do
    let(:url) { "http://www.test-url.com/kubernetes/namespaces/#{namespace.id}" }

    it "is a hash" do
      namespace.manifest.must_equal(
        apiVersion: "v1",
        kind: "Namespace",
        metadata: {name: "test", annotations: {"samson/url": url}, labels: {team: "foo"}}
      )
    end

    it "merges template" do
      namespace.template = {"metadata" => {"name" => "no", "foo" => "bar"}}.to_yaml
      namespace.manifest.must_equal(
        apiVersion: "v1",
        kind: "Namespace",
        metadata: {name: "test", foo: "bar", annotations: {"samson/url": url}}
      )
    end
  end
end
