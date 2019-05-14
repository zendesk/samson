# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Namespace do
  let(:namespace) { kubernetes_namespaces(:test) }

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
end
