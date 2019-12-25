# frozen_string_literal: true

module SamsonPrerequisiteStages
  class SamsonPlugin < Rails::Engine
  end

  def self.validate_deployed_to_all_prerequisite_stages(stage, reference, commit)
    return unless missing = stage.undeployed_prerequisite_stages(commit).presence
    stage_names = missing.map(&:name).join(', ')
    "Reference '#{reference}' has not been deployed to these prerequisite stages: #{stage_names}."
  end

  Samson::Hooks.view :stage_form, 'samson_prerequisite_stages'
  Samson::Hooks.view :stage_show, 'samson_prerequisite_stages'

  Samson::Hooks.callback :before_deploy do |deploy, _|
    # This check is technically redundant (undeployed_prerequisite_stages above will be empty anyway if this
    # is not true) but a whole bunch of unrelated tests will complain about a missing HTTP stub from resolving
    # the ref to a commit if we don't do this.
    next unless deploy.stage.prerequisite_stage_ids?
    error = SamsonPrerequisiteStages.validate_deployed_to_all_prerequisite_stages(
      deploy.stage, deploy.reference, deploy.project.repo_commit_from_ref(deploy.reference)
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
