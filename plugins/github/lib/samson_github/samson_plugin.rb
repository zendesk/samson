# frozen_string_literal: true
module SamsonGithub
  # Reference: https://www.githubstatus.com/api#status
  # Official doc example is: https://kctbh9vrtdwd.statuspage.io',
  # however 'https://www.githubstatus.com' also works
  STATUS_URL = ENV["GITHUB_STATUS_URL"] || 'https://www.githubstatus.com'

  class SamsonPlugin < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_github"

Samson::Hooks.callback :stage_permitted_params do
  [
    :update_github_pull_requests,
    :use_github_deployment_api,
    :github_pull_request_comment
  ]
end

Samson::Hooks.callback :before_deploy do |deploy, _|
  next unless deploy.stage.use_github_deployment_api?
  deploy.instance_variable_set(:@deployment, GithubDeployment.new(deploy).create)
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
    # From this reference: https://www.githubstatus.com/api#status
    # Get the status rollup for the whole page. This endpoint includes an indicator -
    # one of none, minor, major, or critical, as well as a human description of the blended component status.
    response = Faraday.get("#{SamsonGithub::STATUS_URL}/api/v2/status.json") do |req|
      req.options.timeout = req.options.open_timeout = 1
    end
    error unless response.status == 200 && JSON.parse(response.body)['status']['indicator'] == 'none'
  rescue StandardError
    error
  end
end

Samson::Hooks.callback :repo_commit_from_ref do |project, reference|
  next unless project.github?
  GITHUB.commit(project.repository_path, reference).sha
end

Samson::Hooks.callback :repo_compare do |project, previous_commit, reference|
  next unless project.github?
  GITHUB.compare(project.repository_path, previous_commit, reference)
end
