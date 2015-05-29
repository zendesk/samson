module SamsonPipelines
  class Engine < Rails::Engine
  end

  class << self
    def start_pipelined_stages(job, output)
      return if !job.deploy || job.deploy.stage.next_stage_ids.empty?

      Stage.find(job.deploy.stage.next_stage_ids).each do |next_stage|
        new_deploy = DeployService.new(job.deploy.user).deploy!(next_stage, reference: job.deploy.commit)
        output.write("\n# Kicking off next stage: #{next_stage.name} - URL: #{new_deploy.url}\n")
      end
    rescue => ex
      raise "Failed to start the next deploys in the pipeline: #{ex.message} - #{ex.backtrace}"
    end
  end
end

Samson::Hooks.view :stage_form, 'samson_pipelines/fields'

Samson::Hooks.callback :stage_permitted_params do
  { next_stage_ids: [] }
end

Samson::Hooks.callback :before_execute_finish_msg do |job, output|
  SamsonPipelines.start_pipelined_stages(job, output)
end
