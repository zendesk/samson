# frozen_string_literal: true

module SamsonPrerequisiteStages
  class Engine < Rails::Engine
    def self.execute_if_unmet_prereq_stages(stage, reference)
      if unmet_prereq_stages = stage.unmet_prerequisite_stages(reference).presence
        stage_names = unmet_prereq_stages.map(&:name).join(', ')
        error = "Reference '#{reference}' has not been deployed to these prerequisite stages: #{stage_names}."
        yield error
      end
    end
  end

  Samson::Hooks.view :stage_form, 'samson_prerequisite_stages/stage_form'
  Samson::Hooks.view :stage_show, 'samson_prerequisite_stages/stage_show'

  Samson::Hooks.callback :before_deploy do |deploy, _buddy|
    SamsonPrerequisiteStages::Engine.execute_if_unmet_prereq_stages(deploy.stage, deploy.reference) do |error_message|
      raise error_message
    end
  end

  Samson::Hooks.callback :ref_status do |stage, reference|
    SamsonPrerequisiteStages::Engine.execute_if_unmet_prereq_stages(stage, reference) do |error_message|
      break {
        state: 'fatal',
        statuses: [{
          state: 'Unmet Prerequisite Stages',
          description: error_message
        }]
      }
    end
  end

  Samson::Hooks.callback :stage_permitted_params do
    {prerequisite_stage_ids: []}
  end
end
