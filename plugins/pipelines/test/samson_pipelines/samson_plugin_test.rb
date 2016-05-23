require_relative '../test_helper'

SingleCov.covered! uncovered: 6 unless defined?(Rake) # rake preloads all plugins

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
      user: User.first,
      deploy: deploy
    )
  end

  describe :after_job_execution do
    it 'kicks off the next stages in the deploy' do
      stage.update!(next_stage_ids: next_stages.map(&:id))
      DeployService.any_instance.expects(:deploy!).with(stages(:test_production),     reference: 'staging')
      DeployService.any_instance.expects(:deploy!).with(stages(:test_production_pod), reference: 'staging')
      Samson::Hooks.fire(:after_job_execution, job, true, output)
    end

    it 'does not kick off the next stage in the pipeline if current stage failed' do
      stage.update!(next_stage_ids: next_stages.map(&:id))
      DeployService.any_instance.expects(:deploy!).never
      Samson::Hooks.fire(:after_job_execution, job, false, output)
    end

    it 'does not deploy another if the next_stage_id is nil' do
      DeployService.any_instance.expects(:deploy!).never
      Samson::Hooks.fire(:after_job_execution, job, true, output)
    end

    it 'does not deploy another if the deploy is nil' do
      job = Job.create(project: stage.project, command: "echo", status: "running", user: User.first)
      DeployService.any_instance.expects(:deploy!).never
      Samson::Hooks.fire(:after_job_execution, job, true, output)
    end
  end
end
