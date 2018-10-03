# frozen_string_literal: true
module SamsonDeployEnvVars
  class Engine < Rails::Engine
  end
end

# Adds the deploy env vars view to the deploy form in order to add
# specific environment vars per deploy
Samson::Hooks.view :deploy_form, 'samson_deploy_env_vars/deploy_form'

# Allows environment vars as valid parameters for the deploy model
Samson::Hooks.callback :deploy_permitted_params do
  AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
end

# Injects specific environment variables for the deploy when they were set in the form
# NOTE: does not resolve secrets or dollar variables on purpose
Samson::Hooks.callback :deploy_env do |deploy|
  deploy.environment_variables.each_with_object({}) { |var, h| h[var.name] = var.value }
end
