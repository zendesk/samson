# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonKubernetes do
  describe :stage_permitted_params do
    it "adds outs" do
      Samson::Hooks.fire(:stage_permitted_params).must_include :kubernetes
    end
  end

  describe :deploy_permitted_params do
    it "adds outs" do
      Samson::Hooks.fire(:deploy_permitted_params).must_include :kubernetes_rollback
    end
  end

  describe :build_permitted_params do
    it "adds outs" do
      Samson::Hooks.fire(:build_permitted_params).must_include :kubernetes_job
    end
  end
end
