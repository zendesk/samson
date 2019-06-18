# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe DeployGroupRolesHelper do
  include ApplicationHelper

  let(:dgr) { kubernetes_deploy_group_roles(:test_pod1_app_server) }
  let(:role) { dgr.kubernetes_role }

  describe "#kubernetes_deploy_group_role_replica" do
    it "shows a simple count" do
      kubernetes_deploy_group_role_replica(role, dgr).must_equal "3"
    end

    it "shows autoscaled" do
      role.autoscaled = true
      kubernetes_deploy_group_role_replica(role, dgr).must_include "3 <i title=\"Replicas managed"
    end

    it "shows deleted" do
      dgr.delete_resource = true
      kubernetes_deploy_group_role_replica(role, dgr).must_include "<i title=\"Marked"
    end
  end
end
