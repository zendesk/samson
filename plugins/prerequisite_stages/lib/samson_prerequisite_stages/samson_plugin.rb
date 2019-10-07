# frozen_string_literal: true

module SamsonPrerequisiteStages
  class Engine < Rails::Engine
  end

  def self.validate_deployed_to_all_prerequisite_stages(stage, reference, commit)
    return unless missing = stage.undeployed_prerequisite_stages(commit).presence
    stage_names = missing.map(&:name).join(', ')
    "Reference '#{reference}' has not been deployed to these prerequisite stages: #{stage_names}."
  end

  Samson::Hooks.view :stage_form, 'samson_prerequisite_stages'
  Samson::Hooks.view :stage_show, 'samson_prerequisite_stages'

  Samson::Hooks.callback :before_deploy do |deploy, _|
    error = SamsonPrerequisiteStages.validate_deployed_to_all_prerequisite_stages(
      deploy.stage, deploy.reference, deploy.commit
    )
    raise error if error
  end

  Samson::Hooks.callback :ref_status do |stage, reference, commit|
    if error = SamsonPrerequisiteStages.validate_deployed_to_all_prerequisite_stages(stage, reference, commit)
      {
        state: 'fatal',
        statuses: [{
          state: 'Unmet Prerequisite Stages',
          description: error
        }]
      }
    end
  end

  Samson::Hooks.callback :stage_permitted_params do
    {prerequisite_stage_ids: []}
  end
end
