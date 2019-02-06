# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Deploy do
  describe "#copy_kubernetes_from_stage" do
    let(:stage) { stages(:test_staging) }

    def create_deploy
      Deploy.create!(
        stage: stage,
        reference: "baz",
        job: jobs(:succeeded_test),
        project: stage.project
      )
    end

    it "copies kubernetes" do
      stage.kubernetes = true
      create_deploy.kubernetes.must_equal true
    end

    it "does not copy no kubernetes" do
      create_deploy.kubernetes.must_equal false
    end
  end

  describe "#delete_kubernetes_deploy_group_roles" do
    let(:role) { kubernetes_roles(:app_server) }
    let(:project) { role.project }
    it "cleanes up deploy group roles on delete" do
      deploy_group = deploy_groups(:pod2)
      Kubernetes::DeployGroupRole.create!(
        kubernetes_role: role,
        project: project,
        replicas: 1,
        requests_cpu: 0.5,
        requests_memory: 5,
        limits_cpu: 1,
        limits_memory: 10,
        deploy_group: deploy_group
      )
      deploy_group.kubernetes_deploy_group_roles.wont_equal []
      deploy_group.soft_delete!(validate: false)
      deploy_group.reload.kubernetes_deploy_group_roles.must_equal []
    end
  end
end
