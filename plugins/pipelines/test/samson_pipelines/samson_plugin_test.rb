# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonPipelines do
  let(:deploy) { deploys(:succeeded_test) }
  let(:next_deploy) { deploys(:succeeded_production_test) }
  let(:stage) { deploy.stage }
  let(:next_stages) { [stages(:test_production), stages(:test_production_pod)] }
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

  describe :after_job_execution do
    before { stage.update!(next_stage_ids: next_stages.map(&:id)) }

    it 'kicks off the next stages in the deploy' do
      DeployService.any_instance.expects(:deploy).
        with(stages(:test_production), reference: 'staging', buddy: nil, triggering_deploy: deploy).returns(deploy)
      DeployService.any_instance.expects(:deploy).
        with(stages(:test_production_pod), reference: 'staging', buddy: nil, triggering_deploy: deploy).returns(deploy)
      Samson::Hooks.fire(:after_job_execution, job, true, output)
      output.string.must_equal "# Pipeline: Started stage: 'Production' - #{deploy.url}\n" \
        "# Pipeline: Started stage: 'Production Pod' - #{deploy.url}\n"
    end

    it 'does not kick off the next stage in the pipeline if current stage failed' do
      DeployService.any_instance.expects(:deploy).never
      Samson::Hooks.fire(:after_job_execution, job, false, output)
      output.string.must_equal ""
    end

    it 'does not deploy another if the next_stage_id is nil' do
      stage.update!(next_stage_ids: nil)
      DeployService.any_instance.expects(:deploy).never
      Samson::Hooks.fire(:after_job_execution, job, true, output)
      output.string.must_equal ""
    end

    it 'does not deploy another if the deploy is nil' do
      job = Job.create(project: stage.project, command: "echo", status: "running", user: User.first)
      DeployService.any_instance.expects(:deploy).never
      Samson::Hooks.fire(:after_job_execution, job, true, output)
      output.string.must_equal ""
    end

    it 'raises general exceptions' do
      job.expects(:deploy).raises("Whoops")
      e = assert_raises RuntimeError do
        Samson::Hooks.fire(:after_job_execution, job, true, output)
      end
      e.message.must_equal "Whoops"
    end

    it 'prints stage exceptions to the stream' do
      DeployService.any_instance.expects(:deploy).times(2).raises("Whoops")
      Samson::Hooks.fire(:after_job_execution, job, true, output)
      output.string.must_equal "# Pipeline: Failed to start stage 'Production': Whoops\n" \
        "# Pipeline: Failed to start stage 'Production Pod': Whoops\n"
    end

    it "shows when next stage failed to start" do
      deploy = Deploy.new
      deploy.errors.add :base, 'Foo'
      DeployService.any_instance.expects(:deploy).times(2).returns(deploy)
      Samson::Hooks.fire(:after_job_execution, job, true, output)
      output.string.must_equal "# Pipeline: Failed to start stage 'Production': Foo\n" \
        "# Pipeline: Failed to start stage 'Production Pod': Foo\n"
    end

    it "correctly passes down buddy check to subsequent deploys" do
      deploy.expects(:buddy).twice.returns(users(:admin)) # Buddy check acquired for top level deploy
      Stage.any_instance.expects(:deploy_requires_approval?).twice.returns(true)
      DeployService.any_instance.expects(:confirm_deploy).twice

      Samson::Hooks.fire(:after_job_execution, job, true, output)

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
    let(:view_context) do
      view_context = ActionView::Base.new(ActionController::Base.view_paths)

      class << view_context
        include Rails.application.routes.url_helpers
      end

      view_context
    end

    describe 'deploys_header callback' do
      def render_view
        Samson::Hooks.render_views(:deploys_header, view_context, deploy: deploy)
      end

      let(:deploy) { deploys(:succeeded_test) }

      it 'renders alert if there is a triggering deploy' do
        other_deploy = deploys(:succeeded_production_test)
        deploy.update_column(:triggering_deploy_id, other_deploy.id)

        html = render_view
        html.must_match 'alert-info'
        html.must_match "<a href=\"/projects/foo/deploys/#{other_deploy.id}"
      end

      it 'renders nothing if there is no triggering deploy' do
        render_view.must_equal "\n"
      end
    end
  end
end
