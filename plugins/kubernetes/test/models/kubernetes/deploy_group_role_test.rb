# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployGroupRole do
  let(:stage) { stages(:test_staging) }
  let(:deploy_group_role) { kubernetes_deploy_group_roles(:test_pod1_app_server) }
  let(:deploy_group) { deploy_group_role.deploy_group }
  let(:project) { stage.project }
  let(:usage_limit) { Kubernetes::UsageLimit.create!(scope: deploy_group, project: project, cpu: 1, memory: 400) }

  describe "validations" do
    it "is valid" do
      assert_valid deploy_group_role
    end

    it "is invalid without cpu" do
      deploy_group_role.limits_cpu = nil
      refute_valid deploy_group_role
    end

    it "is invalid without memory" do
      deploy_group_role.limits_memory = nil
      refute_valid deploy_group_role
    end

    it "is valid with 0 cpu requested" do
      deploy_group_role.requests_cpu = 0
      assert_valid deploy_group_role
    end

    it "is invalid with 0 memory requested since everything needs memory" do
      deploy_group_role.requests_memory = 0
      refute_valid deploy_group_role
    end

    it "is invalid with negative cpu requested" do
      deploy_group_role.requests_cpu = -1
      refute_valid deploy_group_role
    end

    it "is invalid with infinite cpu" do
      deploy_group_role.limits_cpu = 0
      refute_valid deploy_group_role
    end

    it "is invalid with infinite memory" do
      deploy_group_role.limits_memory = 0
      refute_valid deploy_group_role
    end

    it "is invalid if a duplicate of it already exists" do
      dgr = deploy_group_role
      new_dgr = Kubernetes::DeployGroupRole.new(
        project_id: dgr.project_id,
        deploy_group_id: dgr.deploy_group_id,
        kubernetes_role_id: dgr.kubernetes_role_id
      )

      refute_valid new_dgr
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
      kubernetes_roles(:app_server).soft_delete!(validate: false)
      Kubernetes::DeployGroupRole.matrix(stage).must_equal(
        [[
          stage.deploy_groups.first,
          [
            [kubernetes_roles(:resque_worker), kubernetes_deploy_group_roles(:test_pod100_resque_worker)]
          ]
        ]]
      )
    end

    it "ignores stage-roles that are ignored" do
      stage.kubernetes_stage_roles.create!(kubernetes_role: kubernetes_roles(:resque_worker), ignored: true)
      Kubernetes::DeployGroupRole.matrix(stage).must_equal(
        [[
          stage.deploy_groups.first,
          [
            [kubernetes_roles(:app_server), kubernetes_deploy_group_roles(:test_pod100_app_server)]
          ]
        ]]
      )
    end
  end

  describe ".usage" do
    it "builds a hash" do
      result = Kubernetes::DeployGroupRole.usage
      pod1 = result.fetch(deploy_groups(:pod1).id)
      pod1["cpu"].to_f.must_equal 1.3
      pod1["memory"].must_equal 640
    end
  end

  describe ".seed!" do
    describe "with missing role" do
      def seed!
        Kubernetes::DeployGroupRole.seed!(stage).map(&:errors).flat_map(&:full_messages)
      end

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
        kubernetes_deploy_group_roles(:test_pod100_app_server).delete
        GitRepository.any_instance.stubs(file_content: content)
      end

      it "fills in missing roles" do
        seed!.must_equal []
        created_role.limits_cpu.must_equal 0.5
        created_role.limits_memory.must_equal 100
        created_role.replicas.must_equal 2
      end

      it "does nothing when there is no deployment" do
        Kubernetes::Util.expects(:parse_file).returns([])
        seed!.must_equal ["Role has no defaults"]
        refute created_role
      end

      it "does nothing when there are no limits" do
        assert content.sub!('resources', 'no_resources')
        seed!.must_equal ["Role has no defaults"]
        refute created_role
      end

      describe "when role would be above limits" do
        before { Kubernetes::UsageLimit.create!(cpu: 0.1, memory: 20, scope: environments(:staging)) }

        it "uses limits when role would be invalid" do
          seed!.must_equal []
          created_role.requests_cpu.to_f.must_equal 0.05
          created_role.requests_memory.must_equal 10
          created_role.replicas.must_equal 2
        end

        it "uses regular values for role with 0 replicas" do
          assert content.sub!('replicas: 2', 'replicas: 0')
          seed!.must_equal []
          created_role.requests_cpu.to_f.must_equal 0.25
          created_role.replicas.must_equal 0
        end
      end

      describe "when role would be above 0 limits" do
        before { Kubernetes::UsageLimit.create!(cpu: 0, memory: 0) }

        it "lets the role be invalid" do
          seed!.to_s.must_include "Requests cpu (0.25 * 2) must be less than"
        end
      end

      it "ignores invalid roles" do
        assert content.sub!('cpu: 500m', 'cpu: 100m') # limit below requests
        seed!.must_equal ["Requests cpu must be less than or equal to the limit"]
        created_role.must_be_nil
      end
    end
  end

  describe "#requests_below_limits" do
    it "is not valid when requests is above limits" do
      deploy_group_role.requests_cpu = deploy_group_role.limits_cpu * 1.1
      deploy_group_role.requests_memory = deploy_group_role.limits_memory * 1.1
      refute_valid deploy_group_role
      deploy_group_role.errors.full_messages.must_equal(
        [
          "Requests cpu must be less than or equal to the limit",
          "Requests memory must be less than or equal to the limit"
        ]
      )
    end
  end

  describe "#limits_close_to_requests" do
    it "shows no error when limits are ok" do
      assert_valid deploy_group_role
    end

    it "allows 0 with up to 1 cpu" do
      deploy_group_role.requests_cpu = 0
      deploy_group_role.limits_cpu = 1.0
      assert_valid deploy_group_role
    end

    it "shows an error if the limits are more than 10x the requests" do
      deploy_group_role.limits_cpu = 2.0
      deploy_group_role.limits_memory = 2048
      refute_valid deploy_group_role
      deploy_group_role.errors.full_messages.must_equal(
        [
          "Limits cpu must be less than 10x requested cpu",
          "Limits memory must be less than 10x requested memory"
        ]
      )
    end
  end

  describe "#requests_below_usage_limits" do
    before { usage_limit }

    it "is valid without usage_limit" do
      usage_limit.destroy
      assert_valid deploy_group_role
    end

    it "is valid when requests are equal to usage_limit" do
      assert_valid deploy_group_role
    end

    it "does not blow up when requests_* is not set" do
      deploy_group_role.requests_cpu = nil
      deploy_group_role.requests_memory = nil
      deploy_group_role.replicas = nil
      refute_valid deploy_group_role
      deploy_group_role.errors.full_messages.must_equal(
        [
          "Requests cpu can't be blank",
          "Requests cpu is not a number",
          "Requests memory can't be blank",
          "Requests memory is not a number",
          "Replicas can't be blank"
        ]
      )
    end

    describe "when requests are above usage_limit" do
      before do
        deploy_group_role.requests_cpu = deploy_group_role.limits_cpu = 1
        deploy_group_role.requests_memory = 200
      end

      it "is not valid when " do
        refute_valid deploy_group_role
        deploy_group_role.errors.full_messages.must_equal(
          [
            "Requests cpu (1.0 * 3) must be less than or equal to kubernetes usage limit 1.0 (##{usage_limit.id})",
            "Requests memory (200 * 3) must be less than or equal to kubernetes usage limit 400 (##{usage_limit.id})"
          ]
        )
      end

      it "adds custom wanring" do
        with_env KUBERNETES_USAGE_LIMIT_WARNING: 'Stay under the limit dammit!' do
          refute_valid deploy_group_role
        end
        deploy_group_role.errors.full_messages.must_equal(
          [
            "Requests cpu (1.0 * 3) must be less than or equal to kubernetes usage limit 1.0 (##{usage_limit.id})." \
            " Stay under the limit dammit!",
            "Requests memory (200 * 3) must be less than or equal to kubernetes usage limit 400 (##{usage_limit.id})." \
            " Stay under the limit dammit!"
          ]
        )
      end
    end
  end

  describe "#delete_on_0_replicas" do
    it "is valid without usage_limit" do
      deploy_group_role.delete_resource = true
      refute_valid deploy_group_role
    end
  end
end
