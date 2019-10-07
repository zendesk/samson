# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Project do
  let(:project) { projects(:test) }

  before { project.stubs(:valid_repository_url) }

  describe "#kubernetes_deploy_group_roles" do
    it "cleans them up when getting destroyed" do
      assert_difference 'Kubernetes::DeployGroupRole.count', -4 do
        project.destroy
      end
    end

    it "cleans them up when getting soft deleted" do
      assert_difference 'Kubernetes::DeployGroupRole.count', -4 do
        project.soft_delete!(validate: false)
      end
    end
  end

  describe "#kubernetes_roles" do
    it "cleans them up when getting destroyed" do
      assert_difference 'Kubernetes::Role.count', -2 do
        project.destroy
      end
    end

    it "cleans them up when getting soft deleted" do
      assert_difference 'Kubernetes::Role.not_deleted.count', -2 do
        project.soft_delete!(validate: false)
      end
    end
  end

  describe "#override_resource_names?" do
    it "is disabled when namespace is used" do
      assert project.override_resource_names?
      project.create_kubernetes_namespace!(name: "bar")
      refute project.override_resource_names?
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
