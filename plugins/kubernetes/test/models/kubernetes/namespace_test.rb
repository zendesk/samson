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

    it "is not valid when capitalized" do
      namespace.name = "Test"
      refute_valid namespace
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
        namespace.update_attributes!(project_ids: [project.id]) # do what controller does
      end
      role = kubernetes_roles(:app_server)
      role.resource_name.must_be_nil
      role.service_name.must_be_nil
    end

    it "skips clean roles" do
      Kubernetes::Role.update_all(resource_name: nil, service_name: nil)
      assert_difference "Audited::Audit.count", 1 do
        project.create_kubernetes_namespace!(name: "bar")
      end
    end
  end
end
