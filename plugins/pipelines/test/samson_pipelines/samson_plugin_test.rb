# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

def fire
  Samson::Hooks.fire(:after_deploy, deploy, stub(output: output))
end

describe SamsonPipelines do
  let(:deploy) { deploys(:succeeded_test) }
  let(:next_deploy) { deploys(:succeeded_production_test) }
  let(:stage) { deploy.stage }
  let(:pipeline_next_stages) { [stages(:test_production), stages(:test_production_pod)] }
  let(:output) { StringIO.new }
  let(:job) do
    Job.create(
      project: stage.project,
      command: "echo hello world",
      status: "running",
      user: users(:viewer),
      deploy: deploy
    )
  end

  describe :after_deploy do
    before { stage.update!(next_stage_ids: pipeline_next_stages.map(&:id)) }

    it 'kicks off the next stages in the deploy' do
      DeployService.any_instance.expects(:deploy).
        with(stages(:test_production), reference: 'staging', buddy: nil, triggering_deploy: deploy).returns(deploy)
      DeployService.any_instance.expects(:deploy).
        with(stages(:test_production_pod), reference: 'staging', buddy: nil, triggering_deploy: deploy).returns(deploy)
      fire
      output.string.must_equal "# Pipeline: Started stage: 'Production' - #{deploy.url}\n" \
        "# Pipeline: Started stage: 'Production Pod' - #{deploy.url}\n"
    end

    it 'does not kick off the next stage in the pipeline if current stage failed' do
      DeployService.any_instance.expects(:deploy).never
      deploy.job.status = "errored"
      fire
      output.string.must_equal ""
    end

    it 'does not deploy another if the next_stage_id is nil' do
      stage.update!(next_stage_ids: nil)
      DeployService.any_instance.expects(:deploy).never
      fire
      output.string.must_equal ""
    end

    it 'prints stage exceptions to the stream' do
      DeployService.any_instance.expects(:deploy).times(2).raises("Whoops")
      fire
      output.string.must_equal "# Pipeline: Failed to start stage 'Production': Whoops\n" \
        "# Pipeline: Failed to start stage 'Production Pod': Whoops\n"
    end

    it "shows when next stage failed to start" do
      deploy = Deploy.new
      deploy.errors.add :base, 'Foo'
      DeployService.any_instance.expects(:deploy).times(2).returns(deploy)
      fire
      output.string.must_equal "# Pipeline: Failed to start stage 'Production': Foo\n" \
        "# Pipeline: Failed to start stage 'Production Pod': Foo\n"
    end

    it "correctly passes down buddy check to subsequent deploys" do
      deploy.expects(:buddy).twice.returns(users(:admin)) # Buddy check acquired for top level deploy
      Stage.any_instance.expects(:deploy_requires_approval?).twice.returns(true)
      DeployService.any_instance.expects(:confirm_deploy).twice

      fire

      output.string.must_include "# Pipeline: Started stage: 'Production'"
      output.string.must_include "# Pipeline: Started stage: 'Production Pod'"
    end
  end

  describe :stage_permitted_params do
    it "lists extra keys" do
      Samson::Hooks.fire(:stage_permitted_params).must_include next_stage_ids: []
    end
  end

  describe 'view callbacks' do
    describe 'deploys_header callback' do
      def render_view
        Samson::Hooks.render_views(:deploys_header, view_context, deploy: deploy)
      end

      let(:deploy) { deploys(:succeeded_test) }

      before { view_context.instance_variable_set(:@project, Project.first) }

      it 'renders alert if there is a triggering deploy' do
        other_deploy = deploys(:succeeded_production_test)
        deploy.update_column(:triggering_deploy_id, other_deploy.id)

        html = render_view
        html.must_include 'alert-info'
        html.must_include "<a href=\"/projects/foo/deploys/#{other_deploy.id}"
      end

      it 'renders nothing if there is no triggering deploy' do
        render_view.must_equal "\n"
      end
    end
  end
end
