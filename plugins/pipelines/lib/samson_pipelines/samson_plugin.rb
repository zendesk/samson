module SamsonPipelines
  class Engine < Rails::Engine
  end

  class << self
    def start_pipelined_stages(job, success, output)
      return if !success || !job.deploy || job.deploy.stage.next_stage_ids.empty?

      deploy_service = DeployService.new(job.deploy.user)
      job.deploy.stage.next_stages.each do |next_stage|
        start_next_stage(next_stage, job, deploy_service, output)
      end
    rescue => ex
      output.write("Failed to start the pipelined stages: #{ex.message}")
    end

    private

    def start_next_stage(next_stage, current_job, deploy_service, output)
      deploy = deploy_service.deploy!(next_stage, reference: current_job.deploy.reference)
      if !deploy.persisted?
        output.puts "# Pipeline: Failed to start the next stage '#{next_stage.name}': #{deploy.errors.full_messages}\n"
      elsif next_stage.deploy_requires_approval?
        deploy.update!(buddy: current_job.deploy.buddy)
        deploy_service.confirm_deploy!(deploy)
      end
      output.puts "# Pipeline: Kicked off next stage: #{next_stage.name} - URL: #{deploy.url}\n"
    rescue => ex
      output.puts "# Pipeline: Failed to start the next stage '#{next_stage.name}': #{ex.message}\n"
    end
  end
end

Samson::Hooks.view :stage_form, 'samson_pipelines/fields'

Samson::Hooks.callback :stage_permitted_params do
  { next_stage_ids: [] }
end

Samson::Hooks.callback :after_job_execution do |job, success, output|
  SamsonPipelines.start_pipelined_stages(job, success, output)
end
