# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 8

describe MassRolloutsController do
  def create_stages
    @controller.instance_variable_set(:@deploy_group, deploy_group)
    @controller.send(:create_all_stages)
  end

  let(:deploy_group) { deploy_groups(:pod100) }
  let(:stage) { stages(:test_staging) }

  as_a_project_admin do
    unauthorized :get, :new, deploy_group_id: 1
    unauthorized :post, :deploy, deploy_group_id: 1
    unauthorized :post, :create, deploy_group_id: 1
    unauthorized :delete, :destroy, deploy_group_id: 1
    unauthorized :post, :merge, deploy_group_id: 1
  end

  as_a_super_admin do
    describe "#new" do
      let(:env) { environments(:staging) }
      let(:deploy_group) { DeployGroup.create!(name: 'Pod 101', environment: env) }
      let(:template_stage) { stages(:test_staging) }

      it "finds stages to create" do
        get :new, params: {deploy_group_id: deploy_group}

        refute assigns(:missing_stages).empty?
      end

      it "finds precreated stages" do
        # clone the stage
        stage = Stage.build_clone(template_stage)
        stage.deploy_groups << deploy_group
        stage.name = "foo"
        stage.is_template = false
        stage.save!

        get :new, params: {deploy_group_id: deploy_group}

        refute assigns(:preexisting_stages).empty?
      end
    end

    describe "#deploy" do
      describe "deploy for successful deploys" do
        let(:env) { environments(:staging) }
        let(:pod100) { DeployGroup.create!(name: 'Pod 100', environment: env) }
        let(:pod101) { DeployGroup.create!(name: 'Pod 101', environment: env) }
        let(:stage100) do
          Stage.create!(name: 'Staging 100', project: Project.first, deploy_groups: [pod100], is_template: true)
        end
        let(:stage101) do
          Stage.create!(name: 'Staging 101', project: Project.first, deploy_groups: [pod101], template_stage: stage100)
        end

        before do
          DeployGroup.delete_all
          Deploy.delete_all

          stage100.deploys.create!(
            reference: 'v121',
            project: stage100.project,
            job: Job.create!(
              project: stage100.project,
              user: User.first,
              status: "succeeded",
              command: 'blah'
            )
          )

          stage100.deploys.create!(
            reference: 'v123',
            project: stage101.project,
            job: Job.create!(
              project: stage101.project,
              user: User.first,
              status: "failed",
              command: 'blah'
            )
          )

          stage101.deploys.create!(
            reference: 'master',
            project: stage101.project,
            job: Job.create!(
              project: stage101.project,
              user: User.first,
              status: "succeeded",
              command: 'blah'
            )
          )

          stage101.deploys.create!(
            reference: 'v123',
            project: stage101.project,
            job: Job.create!(
              project: stage101.project,
              user: User.first,
              status: "failed",
              command: 'blah'
            )
          )
        end

        it 'deploys all stages with successful deploys for this deploy_group' do
          assert_difference 'Deploy.count', 1 do
            post :deploy, params: {deploy_group_id: pod100, successful: true, non_kubernetes: true}
          end

          deploy = stage100.deploys.order('created_at desc').first
          assert_redirected_to "/deploys?ids%5B%5D=#{deploy.id}"
        end

        it "redeploys the same reference as the template stage's last successful deploy" do
          assert_difference 'Deploy.count', 1 do
            post :deploy, params: {deploy_group_id: pod101, successful: true, non_kubernetes: true}
          end
          deploy = Deploy.order('created_at desc').first
          assert_equal 'v121', deploy.reference
        end

        it 'ignores stages that have not been deployed yet' do
          stage100.deploys.delete_all

          refute_difference 'Deploy.count' do
            post :deploy, params: {deploy_group_id: pod100, successful: true, non_kubernetes: true}
          end
          assert_redirected_to "/deploys" # with no ids present.
        end

        it 'ignores stages with only a failed deploy' do
          Job.where(id: stage100.deploys.pluck(:job_id)).update_all(status: :failed)

          refute_difference 'Deploy.count' do
            post :deploy, params: {deploy_group_id: pod100, successful: true, non_kubernetes: true}
          end
          assert_redirected_to "/deploys" # with no ids present.
        end

        it 'ignores failed deploy and takes last successful deploy to the template stage' do
          # verify the test is setup correctly.
          assert stage100.last_deploy.failed?
          assert stage100.last_successful_deploy

          assert_difference 'Deploy.count', 1 do
            post :deploy, params: {deploy_group_id: pod101, successful: true, non_kubernetes: true}
          end
          deploy = stage101.deploys.order('created_at desc').first
          assert_equal stage100.last_successful_deploy.reference, deploy.reference
        end

        it 'ignores stages with no deploy groups' do
          DeployGroupsStage.delete_all

          post :deploy, params: {deploy_group_id: pod100, successful: true, non_kubernetes: true}
          assert_redirected_to "/deploys" # with no ids  present.
        end

        it 'ignores stages that include only other deploy groups' do
          env = environments(:staging)
          new_dp = DeployGroup.create!(name: "foo", environment: env)
          DeployGroupsStage.update_all(deploy_group_id: new_dp.id)

          refute_difference 'Deploy.count' do
            post :deploy, params: {deploy_group_id: pod100, successful: true, non_kubernetes: true}
          end
          assert_redirected_to "/deploys" # with no ids  present.
        end
      end
    end

    describe "deploy for missing deploys" do
      let(:env) { environments(:staging) }
      let(:deploy_group) { DeployGroup.create!(name: 'pod102', environment: env) }

      before do
        create_stages

        # Give it a successful deploy
        new_stage = deploy_group.reload.stages.first
        new_stage.deploys.create!(
          reference: 'master',
          project: stage.project,
          job: Job.create!(
            project: stage.project,
            user: User.first,
            status: "succeeded",
            command: 'blah'
          )
        )
      end

      it "deploys undeployed stage" do
        deploy_group.stages.first.deploys.delete_all

        assert_difference 'Deploy.count', 1 do
          post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        end
      end

      it "deploys 'failed deploy' stage with the template_stage reference" do
        deploy_group.stages.first.deploys.last.job.update_column(:status, "failed")
        refute_nil Stage.find(deploy_group.stages.first.template_stage_id).last_successful_deploy

        assert_difference 'Deploy.count', 1 do
          post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        end
      end

      it 'ignores template_stages that have not been deployed yet' do
        Deploy.delete_all

        post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        assert_redirected_to "/deploys" # with no ids  present.
      end

      it 'ignores template_stages with only a failed deploy' do
        Job.update_all(status: :failed)

        post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        assert_redirected_to "/deploys" # with no ids  present.
      end

      it 'ignores template_stages not marked as template stages' do
        deploy_group.environment.template_stages.update_all(is_template: false)

        post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        assert_redirected_to "/deploys" # with no ids  present.
      end

      it 'ignores projects with no template stage for this environment' do
        Stage.update_all(template_stage_id: nil)

        post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        assert_redirected_to "/deploys" # with no ids  present.
      end

      it "ignores 'successfully deployed' stage" do
        refute_difference 'Deploy.count' do
          post :deploy, params: {deploy_group_id: deploy_group, missing: true, non_kubernetes: true}
        end
      end

      describe 'deploy for kubernetes stages' do
        let(:cluster) { kubernetes_clusters(:test_cluster) }
        let(:template_stage) { deploy_group.environment.template_stages.first }
        let(:k8s_stage) do
          Stage.create!(
            name: 'Staging K8s',
            project: template_stage.project,
            template_stage: template_stage,
            kubernetes: true,
            deploy_groups: [deploy_group]
          )
        end

        before do
          Kubernetes::Cluster.any_instance.stubs(connection_valid?: true, namespaces: ['staging'])
          Kubernetes::ClusterDeployGroup.create!(cluster: cluster, deploy_group: deploy_group, namespace: 'staging')

          k8s_stage.save!
        end

        it 'deploys already deployed k8s stages' do
          k8s_stage.deploys.create!(
            reference: 'v123',
            project: stage.project,
            job: Job.create!(
              project: stage.project,
              user: User.first,
              status: "succeeded",
              command: 'blah'
            )
          )

          assert_difference 'Deploy.count', 1 do
            post :deploy, params: {deploy_group_id: deploy_group, successful: true, kubernetes: true}
          end

          deploy = k8s_stage.deploys.order('created_at desc').first
          assert_redirected_to "/deploys?ids%5B%5D=#{deploy.id}"
        end

        it 'deploys missing k8s stages' do
          assert_difference 'Deploy.count', 1 do
            post :deploy, params: {deploy_group_id: deploy_group, missing: true, kubernetes: true}
          end

          deploy = k8s_stage.deploys.order('created_at desc').first
          assert_redirected_to "/deploys?ids%5B%5D=#{deploy.id}"
          assert_equal template_stage.last_successful_deploy.reference, deploy.reference
        end

        it 'ignores non-kubernetes stages' do
          refute_difference 'Deploy.count' do
            post :deploy, params: {deploy_group_id: deploy_group, successful: true, kubernetes: true}
          end
        end
      end
    end

    describe "#create" do
      let(:env) { environments(:staging) }
      let(:deploy_group) { DeployGroup.create!(name: 'Pod 101', environment: env) }
      let(:template_stage) { stages(:test_staging) }

      it 'creates no stages if there are no template_environments' do
        template_stage.update(is_template: false)
        assert_no_difference 'Stage.count' do
          post :create, params: {deploy_group_id: deploy_group}
        end
      end

      it 'creates a missing stage for a template_environment' do
        assert_difference 'Stage.count', 1 do
          post :create, params: {deploy_group_id: deploy_group}
        end

        refute_empty deploy_group.stages.where(project: template_stage.project)
      end

      it 'adds the new stage to the end of the deploy pipeline' do
        post :create, params: {deploy_group_id: deploy_group}

        # the new stage is at the end of the pipeline
        stage = deploy_group.stages.last
        template_stage.next_stage_ids.must_equal([stage.id])
      end

      it 'creates deploy group roles for new kubernetes stages' do
        Kubernetes::ClusterDeployGroup.any_instance.stubs(:validate_namespace_exists)
        Kubernetes::Role.stubs(:seed!)

        ([deploy_group] + template_stage.deploy_groups).each do |dg|
          Kubernetes::ClusterDeployGroup.create!(
            deploy_group: dg,
            namespace: 'foo',
            cluster: kubernetes_clusters(:test_cluster)
          )
        end

        Kubernetes::DeployGroupRole.where(deploy_group: template_stage.deploy_groups.first).destroy_all

        template_stage.update_column(:kubernetes, true)
        template_dgr = kubernetes_deploy_group_roles(:test_pod1_app_server)
        template_dgr.update_attributes!(deploy_group_id: template_stage.deploy_groups.first.id)

        assert_difference 'Stage.count', 1 do
          post :create, params: {deploy_group_id: deploy_group}
        end

        stage = Stage.last
        stage.kubernetes.must_equal true
        copied_dgr = Kubernetes::DeployGroupRole.where(project: stage.project, deploy_group: deploy_group).first
        ignore = ["id", "created_at", "updated_at", "deploy_group_id"]
        copied_dgr.attributes.except(*ignore).must_equal template_dgr.attributes.except(*ignore)
      end

      describe "multiple stages" do
        let(:url) { "git://foo.com:hello/world.git" }
        let(:project2) do
          Project.any_instance.stubs(:valid_repository_url).returns(true)
          Project.create!(
            name: 'blah',
            repository_url: url,
            include_new_deploy_groups: true
          )
        end
        let(:template_stage2) do
          project2.stages.create!(
            name: 'stage blah',
            deploy_groups: [template_stage.deploy_groups.first],
            is_template: true
          )
        end

        before do
          template_stage
          template_stage2
        end

        it "creates multiple stages" do
          assert_difference 'Stage.count', 2 do
            post :create, params: {deploy_group_id: deploy_group}
          end
        end

        it "reports number of stages created" do
          post :create, params: {deploy_group_id: deploy_group}
          assert_equal("Created 2 Stages", flash[:notice])
        end

        it "ignores errors" do
          @controller.stubs(:create_stage_with_group).raises(StandardError)
          assert_difference 'Stage.count', 0 do
            post :create, params: {deploy_group_id: deploy_group}
          end
          assert_redirected_to deploy_group_path(deploy_group)
        end

        it "reports only the number of stages actually created" do
          @controller.stubs(:create_stage_with_group).raises(StandardError).then.returns("something")

          post :create, params: {deploy_group_id: deploy_group}
          assert_equal("Created 1 Stages", flash[:notice])
        end
      end
    end

    describe "#merge" do
      describe "without a created stage" do
        it "succeeds with no work to do" do
          post :merge, params: {deploy_group_id: deploy_group}
          assert_redirected_to deploy_group_path(deploy_group)
        end
      end

      describe "with a created stage" do
        let(:env) { environments(:staging) }
        let(:deploy_group) { DeployGroup.create!(name: 'Pod 101', environment: env) }
        let(:template_stage) { stages(:test_staging) }

        let :stage do
          create_stages
          deploy_group.stages.where(project: template_stage.project).first
        end

        before do
          assert template_stage
          assert stage
        end

        it "removes the stage" do
          assert_difference 'Stage.count', -1 do
            post :merge, params: {deploy_group_id: deploy_group}
          end
        end

        it "success sets no alert for skipping" do
          post :merge, params: {deploy_group_id: deploy_group}

          refute flash.alert
        end

        it "removes the next_stage_id" do
          assert template_stage.reload.next_stage_ids.include?(stage.id)

          post :merge, params: {deploy_group_id: deploy_group}

          refute template_stage.reload.next_stage_ids.include?(stage.id)
        end

        it "adds the deploy group to the template stage" do
          refute template_stage.deploy_groups.include?(deploy_group)

          post :merge, params: {deploy_group_id: deploy_group}

          assert template_stage.deploy_groups.include?(deploy_group)
        end

        it "removes the stale deploy_group links as well" do
          assert DeployGroupsStage.where(stage_id: stage.id, deploy_group_id: deploy_group.id).first

          post :merge, params: {deploy_group_id: deploy_group}

          refute DeployGroupsStage.where(stage_id: stage.id, deploy_group_id: deploy_group.id).first
        end

        it "replaces the stale stage deploy group link with one for the template stage" do
          refute DeployGroupsStage.where(stage_id: template_stage.id, deploy_group_id: deploy_group.id).first

          post :merge, params: {deploy_group_id: deploy_group}

          assert DeployGroupsStage.where(stage_id: template_stage.id, deploy_group_id: deploy_group.id).first
        end

        describe "commands differ between clone and template" do
          before do
            command = Command.create!(command: "flooboop")
            StageCommand.create!(command: command, stage: stage, position: 2)
          end

          it "ignores clone during merge" do
            # doesn't remove the old stage
            refute_difference 'Stage.count' do
              post :merge, params: {deploy_group_id: deploy_group}
            end

            # doesn't merge the deploy group
            refute template_stage.deploy_groups.include?(deploy_group)
          end

          it "sets warning in alert" do
            post :merge, params: {deploy_group_id: deploy_group}
            assert flash.alert
          end
        end

        describe "stage has no template" do
          before do
            stage.template_stage = nil
            stage.save!
          end

          it "ignores clone during merge" do
            refute_difference 'Stage.count' do
              post :merge, params: {deploy_group_id: deploy_group}
            end

            refute template_stage.deploy_groups.include?(deploy_group)
          end
        end

        describe "stage is a template" do
          before do
            stage.is_template = true
            stage.save!
          end

          it "ignores clone during merge" do
            refute_difference 'Stage.count' do
              post :merge, params: {deploy_group_id: deploy_group}
            end

            refute template_stage.deploy_groups.include?(deploy_group)
          end

          it "sets warning in alert" do
            post :merge, params: {deploy_group_id: deploy_group}
            assert flash.alert
          end
        end

        describe "stage has more than one deploy group" do
          before do
            stage.deploy_groups << DeployGroup.create!(name: 'Pod 102', environment: env)
            stage.save!
          end

          it "ignores clone during merge" do
            refute_difference 'Stage.count' do
              post :merge, params: {deploy_group_id: deploy_group}
            end

            refute template_stage.deploy_groups.include?(deploy_group)
          end

          it "sets warning in alert" do
            post :merge, params: {deploy_group_id: deploy_group}
            assert flash.alert
          end
        end
      end

      describe "with multiple stages to remove" do
        let(:env) { environments(:staging) }
        let(:template_deploy_group) { deploy_groups(:pod100) } # needed so the templaste stages have an environment.
        let(:deploy_group) { DeployGroup.create!(name: 'Pod 101', environment: env) }

        before do
          Project.any_instance.stubs(:valid_repository_url)
          # create a new template stages, and remember we still have a 2nd from the default fixtures.

          project = Project.create!(
            name: "foo",
            include_new_deploy_groups: true,
            permalink: "foo",
            repository_url: "https://github.com/samson-test-org/example-project.git"
          )
          Stage.create!(name: "foo tstage", project: project, is_template: true, deploy_groups: [template_deploy_group])

          create_stages
        end

        it "merges and soft-deletes all non-template stages" do
          assert_equal 2, deploy_group.stages.count

          post :merge, params: {deploy_group_id: deploy_group}

          # should have only template-stages now (all others were soft-deleted)
          stages = deploy_group.stages.where(is_template: false)
          assert_empty stages
        end
      end
    end

    describe "#destroy" do
      let(:env) { environments(:staging) }
      let(:deploy_group) { DeployGroup.create!(name: 'Pod 101', environment: env) }
      let(:template_stage) { stages(:test_staging) }

      let :stage do
        create_stages
        deploy_group.stages.where(project: template_stage.project).first
      end

      it "deletes a cloned stage" do
        refute stage.reload.deleted?

        delete :destroy, params: {deploy_group_id: deploy_group}

        assert(Stage.with_deleted { stage.reload.deleted? })
      end

      it "ignores a non-cloned stage" do
        stage.template_stage = nil
        stage.save!

        delete :destroy, params: {deploy_group_id: deploy_group}

        refute stage.reload.deleted?
      end

      it "ignores a cloned stage that has been altered (commands)" do
        command = Command.create!(command: "flooboop")
        StageCommand.create!(command: command, stage: stage, position: 2)

        delete :destroy, params: {deploy_group_id: deploy_group}

        refute stage.reload.deleted?
      end
    end
  end
end
