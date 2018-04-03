# frozen_string_literal: true
module SamsonDeployEnvVars
  class Engine < Rails::Engine
    config.after_initialize do
      # Decorates default deploys helper. Maybe there is a better way to do this?
      require_relative '../../app/helpers/deploys_helper'
    end
  end
end

# Adds the deploy env vars view to the deploy form in order to add
# specific environment vars per deploy
Samson::Hooks.view :deploy_form, 'samson_deploy_env_vars/deploy_form'

# Allows environment vars as valid parameters for the deploy model
Samson::Hooks.callback :deploy_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
end

# Injects specific environment variables for the deploy if any
Samson::Hooks.callback :job_additional_vars do |job|
  if job.deploy
    job.deploy.environment_variables.each_with_object({}) do |var, collection|
      collection[var.name] = var.value
      collection
    end
  else
    {}
  end
end
