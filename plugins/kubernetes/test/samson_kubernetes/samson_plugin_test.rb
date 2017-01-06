# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe SamsonKubernetes do
  describe :stage_permitted_params do
    it "adds ours" do
      Samson::Hooks.fire(:stage_permitted_params).must_include :kubernetes
    end
  end

  describe :deploy_permitted_params do
    it "adds ours" do
      params = Samson::Hooks.fire(:deploy_permitted_params).flatten
      params.must_include :kubernetes_rollback
      params.must_include :kubernetes_reuse_build
    end
  end

  describe :build_permitted_params do
    it "adds ours" do
      Samson::Hooks.fire(:build_permitted_params).must_include :kubernetes_job
    end
  end

  describe :deploy_group_permitted_params do
    it "adds ours" do
      params = Samson::Hooks.fire(:deploy_group_permitted_params).flatten
      params.must_include cluster_deploy_group_attributes: [:kubernetes_cluster_id, :namespace]
    end
  end
end
