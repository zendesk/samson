# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 7

describe MassRolloutsController do
  def create_stages
    @controller.instance_variable_set(:@deploy_group, deploy_group)
    @controller.send(:create_all_stages)
  end

  def create_deploy(stage, reference, status)
    stage.deploys.create!(
      reference: reference,
      project: stage.project,
      job: Job.create!(
        project: stage.project,
        user: User.first,
        status: status,
        command: 'blah'
      )
    )
  end

  let(:deploy_group) { deploy_groups(:pod100) }
  let(:stage) { stages(:test_staging) }

  as_a :project_deployer do
    unauthorized :post, :deploy, deploy_group_id: 1
    unauthorized :get, :review_deploy, deploy_group_id: 1
  end

  as_a :deployer do
    describe "#review_deploy" do
      def review_deploy(options = {})
        get :review_deploy, params: {deploy_group_id: deploy_group}.merge(options)
      end

      it "can drive list from console by building a url with needed ids" do
        stage = stages(:test_production)
        review_deploy stage_ids: [stage.id]
        assert_response :success
        assigns(:stages).must_equal [stage]
      end

      it "shows list of matching stages" do
        review_deploy
        assert_response :success
        assigns(:stages).must_equal [stages(:test_staging)]
      end

      describe "status filter" do
        it "complains about unknown status" do
          review_deploy status: "wut"
          assert_response :bad_request
        end

        it "finds undeployed stage" do
          deploy_group.stages.first.deploys.delete_all
          review_deploy status: "missing"
          assigns(:stages).size.must_equal 1
        end

        it "finds deployed stage" do
          review_deploy status: "succeeded"
          assigns(:stages).size.must_equal 1
        end
      end

      describe 'kubernetes filtering' do
        let(:cluster) { kubernetes_clusters(:test_cluster) }

        it "complains about unknown" do
          review_deploy kubernetes: "wut"
          assert_response :bad_request
        end

        it 'finds k8s stages' do
          stages(:test_staging).update_column(:kubernetes, true)
          review_deploy kubernetes: "true"
          assigns(:stages).size.must_equal 1
        end

        it 'ignores non-kubernetes stages' do
          review_deploy kubernetes: "false"
          assigns(:stages).size.must_equal 1
        end
      end
    end

    describe "#deploy" do
      def deploy(options = {})
        post :deploy, params: {
          reference_source: 'template',
          deploy_group_id: deploy_groups(:pod2),
          stage_ids: [stage.id]
        }.merge(options)
      end

      let(:stage) { stages(:test_production) }
      let(:template_stage) { stages(:test_production_pod) }
      let(:template_deploy) { deploys(:succeeded_production_test) }

      before do
        # template stage in same env has a succeeded deploy
        template_stage.update_column(:is_template, true)
        template_deploy.update_column(:stage_id, template_stage.id)
      end

      it "ignores when user selected no stages" do
        post :deploy, params: {reference_source: 'template', deploy_group_id: deploy_groups(:pod2)}
        assert_redirected_to "/deploys"
        flash[:alert].must_be_nil
      end

      it "deploys template reference and redirects to deploy list" do
        assert_difference('Deploy.count', 1) { deploy }
        deploy = stage.deploys.order('created_at desc').first
        assert_redirected_to "/deploys?ids%5B%5D=#{deploy.id}"
        deploy.reference.must_equal template_deploy.reference
      end

      it "re-deploys last succeeded deploy of the stage" do
        template_deploy.update_column(:stage_id, stage.id)
        assert_difference('Deploy.count', 1) { deploy reference_source: 'redeploy' }
        deploy = stage.deploys.order('created_at desc').first
        assert_redirected_to "/deploys?ids%5B%5D=#{deploy.id}"
        deploy.reference.must_equal template_deploy.reference
      end

      it "does not deploy if template only failed to deploy" do
        template_deploy.job.update_column(:status, "errored")
        assert_difference('Deploy.count', 0) { deploy }
        assert_redirected_to "/deploys"
        flash[:alert].must_equal "No reference found http://www.test-url.com/projects/foo/stages/production"
      end

      it "does not deploy if deploy was invalid" do
        Deploy.any_instance.expects(:valid?).returns false
        assert_difference('Deploy.count', 0) { deploy }
        assert_redirected_to "/deploys"
        flash[:alert].must_equal "Validation error http://www.test-url.com/projects/foo/stages/production"
      end

      it "does not overflow the cookie with errors" do
        Deploy.any_instance.expects(:valid?).times(20).returns false
        stages = Array.new(20).fill(stage)
        Stage.expects(:find).returns stages
        assert_difference('Deploy.count', 0) { deploy }
        assert_redirected_to "/deploys"
        alert = flash[:alert]
        alert.size.must_be :<, 1000
        alert.must_include "10 more"
      end

      it "does not deploy if template was never deployed" do
        template_deploy.delete
        assert_difference('Deploy.count', 0) { deploy }
        assert_redirected_to "/deploys"
      end

      it 'ignores stages not marked as template stages' do
        template_stage.update_column(:is_template, false)
        refute_difference('Deploy.count') { deploy }
        assert_redirected_to "/deploys"
      end

      it 'ignores stages that have no template in the same environment' do
        template_stage.deploy_groups.first.update_column(:environment_id, environments(:staging).id)
        refute_difference('Deploy.count') { deploy }
        assert_redirected_to "/deploys"
      end

      it 'ignores stages from other projects' do
        template_stage.update_column(:project_id, 123)
        refute_difference('Deploy.count') { deploy }
        assert_redirected_to "/deploys"
      end

      it "fails on unknown reference_source" do
        deploy reference_source: 'foo'
        assert_response :bad_request
      end
    end
  end

  as_a :project_admin do
    unauthorized :get, :new, deploy_group_id: 1
    unauthorized :post, :create, deploy_group_id: 1
    unauthorized :delete, :destroy, deploy_group_id: 1
    unauthorized :post, :merge, deploy_group_id: 1
  end

  as_a :super_admin do
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
