# frozen_string_literal: true
module EnvironmentVariablesHelper
  def deploy_environment_variable_diff
    return @deploy_environment_variable_diff if defined?(@deploy_environment_variable_diff)
    @deploy_environment_variable_diff = begin
      previous_env = @deploy.stage && @deploy.previous_succeeded_deploy&.env_state
      current_env = @deploy.project && @deploy.retrieve_env_state
      [previous_env, current_env] unless previous_env.presence == current_env.presence
    end
  end
end
