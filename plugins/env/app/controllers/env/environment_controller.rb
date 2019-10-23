# frozen_string_literal: true

module Env
  class EnvironmentController < ApplicationController
    include CurrentProject

    def show
      deploy_group = DeployGroup.find_by_permalink!(params.require(:deploy_group))
      env = EnvironmentVariable.env(Deploy.new(project: current_project), deploy_group, preview: true)
      if unexpanded = unexpanded_secrets(env).presence
        render plain: "Unexpanded secrets found: #{unexpanded.join(', ')}", status: :unprocessable_entity
      else
        render plain: SamsonEnv.generate_dotenv(env)
      end
    end

    def preview
      deploy_groups =
        if deploy_group = params[:deploy_group].presence
          [DeployGroup.find_by_permalink!(deploy_group)]
        else
          DeployGroup.all
        end
      deploy = Deploy.new(project: current_project)
      envs = SamsonEnv.env_groups(deploy, deploy_groups, preview: true, env_group: false)

      render json: {environment_variables: envs || []}
    end

    private

    def unexpanded_secrets(env)
      env.each_value.select do |v|
        v.start_with?(TerminalExecutor::SECRET_PREFIX) &&
          v.end_with?(EnvironmentVariable::FAILED_LOOKUP_MARK)
      end
    end
  end
end
