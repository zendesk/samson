# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployGroupRole do
  let(:stage) { stages(:test_staging) }
  let(:deploy_group_role) { kubernetes_deploy_group_roles(:test_pod1_app_server) }

  describe "validations" do
    it "is valid" do
      assert_valid deploy_group_role
    end

    it "is invalid without cpu" do
      deploy_group_role.cpu = nil
      refute_valid deploy_group_role
    end

    it "is invalid with infinite cpu" do
      deploy_group_role.cpu = 0
      refute_valid deploy_group_role
    end

    it "is invalid with infinite ram" do
      deploy_group_role.ram = 0
      refute_valid deploy_group_role
    end
  end

  describe ".matrix" do
    it "builds a complete matrix" do
      Kubernetes::DeployGroupRole.matrix(stage).must_equal(
        [[
          stage.deploy_groups.first,
          [
            [kubernetes_roles(:app_server), kubernetes_deploy_group_roles(:test_pod100_app_server)],
            [kubernetes_roles(:resque_worker), kubernetes_deploy_group_roles(:test_pod100_resque_worker)]
          ]
        ]]
      )
    end

    it "shows missing roles with nil" do
      kubernetes_deploy_group_roles(:test_pod100_app_server).delete
      Kubernetes::DeployGroupRole.matrix(stage).must_equal(
        [[
          stage.deploy_groups.first,
          [
            [kubernetes_roles(:app_server), nil],
            [kubernetes_roles(:resque_worker), kubernetes_deploy_group_roles(:test_pod100_resque_worker)]
          ]
        ]]
      )
    end

    it "ignores soft deleted roles" do
      kubernetes_roles(:app_server).soft_delete!
      Kubernetes::DeployGroupRole.matrix(stage).must_equal(
        [[
          stage.deploy_groups.first,
          [
            [kubernetes_roles(:resque_worker), kubernetes_deploy_group_roles(:test_pod100_resque_worker)]
          ]
        ]]
      )
    end
  end

  describe "#seed!" do
    describe "with missing role" do
      let(:created_role) do
        Kubernetes::DeployGroupRole.where(
          deploy_group: deploy_groups(:pod100),
          project: stage.project,
          kubernetes_role: kubernetes_roles(:app_server)
        ).first
      end
      let(:content) { read_kubernetes_sample_file('kubernetes_deployment.yml') }

      before do
        kubernetes_deploy_group_roles(:test_pod100_app_server).delete
        GitRepository.any_instance.stubs(file_content: content)
      end

      it "fills in missing roles" do
        assert Kubernetes::DeployGroupRole.seed!(stage)
        created_role.cpu.must_equal 0.5
        created_role.ram.must_equal 95
        created_role.replicas.must_equal 2
      end

      it "does nothing when there is no deployment" do
        Kubernetes::Util.expects(:parse_file).returns([])
        refute Kubernetes::DeployGroupRole.seed!(stage)
        refute created_role
      end

      it "does nothing when there are no limits" do
        assert content.sub!('resources', 'no_resources')
        refute Kubernetes::DeployGroupRole.seed!(stage)
        refute created_role
      end
    end
  end
end
