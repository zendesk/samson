require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployGroupRole do
  let(:stage) { stages(:test_staging) }

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
      let(:content) do
        {
          'kind' => 'Deployment',
          'spec' => {
            'replicas' => 3,
            'template' =>
              {'spec' => {'containers' => [{'resources' => {'limits' => {'ram' => '200Mi', 'cpu' => '250m'}}}]}}
          }
        }.to_yaml
      end

      before do
        kubernetes_deploy_group_roles(:test_pod100_app_server).delete
        GitRepository.any_instance.stubs(file_content: content)
      end

      it "fills in missing roles" do
        assert Kubernetes::DeployGroupRole.seed!(stage)
        created_role.cpu.must_equal 0.25
        created_role.ram.must_equal 200
        created_role.replicas.must_equal 3
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
