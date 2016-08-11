# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Project do
  let(:project) { projects(:test) }

  describe "#kubernetes_deploy_group_roles" do
    it "cleans them up when getting destroyed" do
      assert_difference 'Kubernetes::DeployGroupRole.count', -4 do
        project.destroy
      end
    end
  end

  describe "#kubernetes_roles" do
    it "cleans them up when getting destroyed" do
      assert_difference 'Kubernetes::Role.count', -2 do
        project.destroy
      end
    end
  end

  describe ".with_kubernetes_roles" do
    it "shows projects with kubernetes roles" do
      Project.with_kubernetes_roles.must_equal([projects(:test)])
    end

    it "does not show projects without kubernetes roles" do
      Kubernetes::Role.delete_all
      Project.with_kubernetes_roles.must_equal([])
    end
  end
end
