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

  describe "#name_for_label" do
    it "cleanes up the name" do
      project.name = 'Ab(*c&d-1'
      project.name_for_label.must_equal 'ab-c-d-1'
    end
  end
end
