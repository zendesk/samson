# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ClusterDeployGroup do
  let(:group) { kubernetes_cluster_deploy_groups(:pod1) }

  describe "validations" do
    it "is valid" do
      group.cluster.expects(:namespaces).returns([group.namespace])
      assert_valid group
    end
  end

  describe "#validate_namespace_exists" do
    it "does not validate when cluster is missing" do
      group.cluster = nil
      refute_valid group
    end

    it "is invalid when namespace lookup fails" do
      assert_request(:get, "http://foobar.server/api/v1/namespaces", to_return: {status: 404}) do
        refute_valid group
        group.errors.full_messages.must_equal ["Namespace error looking up namespaces. Cause: 404 Not Found"]
      end
    end

    it "is invalid when namespace does not exist" do
      group.cluster.expects(:namespaces).returns(['foo', 'bar'])
      refute_valid group
      group.errors.full_messages.must_equal ["Namespace named 'pod1' does not exist, found: foo, bar"]
    end
  end
end
