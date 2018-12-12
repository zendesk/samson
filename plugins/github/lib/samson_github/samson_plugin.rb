# frozen_string_literal: true
module SamsonGithub
  STATUS_URL = ENV["GITHUB_STATUS_URL"] || 'https://www.githubstatus.com'

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

Samson::Hooks.callback :before_deploy do |deploy, _|
  if deploy.stage.use_github_deployment_api?
    deploy.instance_variable_set(:@deployment, GithubDeployment.new(deploy).create)
  end
end

Samson::Hooks.callback :after_deploy do |deploy, _|
  if deploy.stage.update_github_pull_requests? && deploy.status == "succeeded"
    GithubNotification.new(deploy).deliver
  end

  if deploy.stage.use_github_deployment_api? && deployment = deploy.instance_variable_get(:@deployment)
    GithubDeployment.new(deploy).update(deployment)
  end
end

Samson::Hooks.callback :repo_provider_status do
  error = "GitHub may be having problems. Please check their status page #{SamsonGithub::STATUS_URL} for details."
  begin
    response = Faraday.get("#{SamsonGithub::STATUS_URL}/api/status.json") do |req|
      req.options.timeout = req.options.open_timeout = 1
    end
    error unless response.status == 200 && JSON.parse(response.body)['status'] == 'good'
  rescue StandardError
    error
  end
end
