# frozen_string_literal: true
module SamsonGithub
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_github/fields"

Samson::Hooks.callback :stage_permitted_params do
  [
    :update_github_pull_requests,
    :use_github_deployment_api
  ]
end

Samson::Hooks.callback :before_deploy do |deploy, _buddy|
  if deploy.stage.use_github_deployment_api?
    deploy.instance_variable_set(:@deployment, GithubDeployment.new(deploy).create_github_deployment)
  end
end

Samson::Hooks.callback :after_deploy do |deploy, _buddy|
  if deploy.stage.update_github_pull_requests? && deploy.status == "succeeded"
    GithubNotification.new(deploy).deliver
  end

  if deploy.stage.use_github_deployment_api?
    GithubDeployment.new(deploy).update_github_deployment_status(deploy.instance_variable_get(:@deployment))
  end
end
