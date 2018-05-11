# frozen_string_literal: true
module SamsonPipelines
  class Engine < Rails::Engine
  end

  class << self
    def start_pipelined_stages(job, success, output)
      return if !success || !job.deploy || job.deploy.stage.next_stage_ids.empty?

      job.deploy.stage.next_stages.each do |next_stage|
        deploy_to_stage(next_stage, job.deploy, output)
      end
    end

    private

    def deploy_to_stage(stage, previous_deploy, output)
      deploy_service = DeployService.new(previous_deploy.user)
      deploy = deploy_service.deploy(
        stage,
        reference: previous_deploy.reference,
        buddy: previous_deploy.buddy,
        triggering_deploy: previous_deploy
      )
      raise deploy.errors.full_messages.join(", ") unless deploy.persisted?

      output.puts "# Pipeline: Started stage: '#{stage.name}' - #{deploy.url}\n"
    rescue => ex
      output.puts "# Pipeline: Failed to start stage '#{stage.name}': #{ex.message}\n"
    end
  end
end

Samson::Hooks.view :stage_form, "samson_pipelines/stage_form"
Samson::Hooks.view :stage_show, "samson_pipelines/stage_show"
Samson::Hooks.view :deploys_header, "samson_pipelines/deploy_header"

Samson::Hooks.callback :stage_permitted_params do
  {next_stage_ids: []}
end

Samson::Hooks.callback :after_job_execution do |job, success, output|
  SamsonPipelines.start_pipelined_stages(job, success, output)
end
